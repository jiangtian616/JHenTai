import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/cancel_exception.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:retry/retry.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/download_progress.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';
import '../utils/eh_executor.dart';
import '../utils/eh_spider_parser.dart';

const String downloadGallerysId = 'downloadGallerysId';
const String imageId = 'imageId';
const String imageHrefsId = 'imageHrefsId';
const String imageUrlId = 'imageUrlId';
const String galleryDownloadProgressId = 'galleryDownloadProgressId';
const String speedComputerId = 'SpeedComputerId';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxController {
  final executor = EHExecutor(
    concurrency: DownloadSetting.downloadTaskConcurrency.value,
    rate: Rate(DownloadSetting.maximum.value, DownloadSetting.period.value),
  );
  static const int retryTimes = 3;
  static const String _metadata = '.metadata';
  static final downloadPath = path.join(PathSetting.getVisibleDir().path, 'download');

  List<GalleryDownloadedData> gallerys = <GalleryDownloadedData>[];
  Map<int, List<AsyncTask>> gid2Tasks = {};
  Map<int, CancelToken> gid2CancelToken = {};
  Map<int, GalleryDownloadProgress> gid2downloadProgress = <int, GalleryDownloadProgress>{};
  Map<int, List<GalleryThumbnail?>> gid2ImageHrefs = {};
  Map<int, List<GalleryImage?>> gid2Images = <int, List<GalleryImage?>>{};
  Map<int, SpeedComputer> gid2SpeedComputer = {};

  static Future<void> init() async {
    io.Directory(downloadPath).createSync(recursive: true);
    Get.put(DownloadService(), permanent: true);
  }

  @override
  onInit() async {
    /// get download info from database
    List<SelectGallerysWithImagesResult> selectGallerysWithImagesResults = await appDb.selectGallerysWithImages().get();

    for (SelectGallerysWithImagesResult result in selectGallerysWithImagesResults) {
      GalleryDownloadedData gallery = GalleryDownloadedData(
        gid: result.gid,
        token: result.token,
        title: result.title,
        category: result.category,
        pageCount: result.pageCount,
        galleryUrl: result.galleryUrl,
        uploader: result.uploader,
        publishTime: result.publishTime,
        downloadStatusIndex: result.galleryDownloadStatusIndex,
        insertTime: result.insertTime,
      );

      if (gallerys.isEmpty || gallerys.last.gid != gallery.gid) {
        _initGalleryDownloadInfoInMemory(gallery, insertAtFirst: false);
        gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.values[result.galleryDownloadStatusIndex];
      }

      /// no image in this gallery has been downloaded
      if (result.url == null) {
        continue;
      }

      GalleryImage image = GalleryImage(
        url: result.url!,
        height: result.height!,
        width: result.width!,
        path: result.path!,
        downloadStatus: DownloadStatus.values[result.imageDownloadStatusIndex!],
      );
      gid2Images[gallery.gid]![result.serialNo!] = image;

      if (image.downloadStatus == DownloadStatus.downloaded) {
        gid2downloadProgress[gallery.gid]!.curCount++;
        gid2downloadProgress[gallery.gid]!.hasDownloaded[result.serialNo!] = true;
      }
    }

    /// resume if status is [downloading]
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        downloadGallery(g, isFirstDownload: false);
      }
    }

    Log.verbose('init DownloadService success, download task count: ${gallerys.length}', false);
    super.onInit();
  }

  /// begin or resume downloading all images of a gallery
  /// step 1: get image href from its thumbnail, if thumbnail haven't been parsed, parse thumbnail first.
  /// step 2: get image url by parsing page (with href parsed last step)
  /// step 3: download image
  Future<void> downloadGallery(GalleryDownloadedData gallery, {bool isFirstDownload = true}) async {
    if (isFirstDownload && gid2downloadProgress.containsKey(gallery.gid)) {
      return;
    }

    Log.info('begin to download gallery: ${gallery.gid}', false);

    /// Firstly record downloaded gallery
    if (isFirstDownload) {
      int success = await _saveNewGalleryDownloadInfoInDatabase(gallery);
      if (success < 0) {
        return;
      }
      _initGalleryDownloadInfoInMemory(gallery);
      if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
        _saveGalleryDownloadInfoInDisk(gallery);
      }
      gid2SpeedComputer[gallery.gid]!.start();
    }

    for (int serialNo = 0; serialNo < gid2downloadProgress[gallery.gid]!.totalCount; serialNo++) {
      /// has downloaded this image
      if (gid2Images[gallery.gid]?[serialNo]?.downloadStatus == DownloadStatus.downloaded) {
        continue;
      }

      /// url has been parsed, download directly
      if (gid2Images[gallery.gid]?[serialNo] != null) {
        _downloadGalleryImage(gallery, serialNo);
        continue;
      }

      /// no parsed href and url, parse from thumbnails first
      if (gid2ImageHrefs[gallery.gid]?[serialNo] == null) {
        await _parseGalleryImageHref(gallery, serialNo);
      }

      /// parse url and then download
      _parseGalleryImageUrl(gallery, serialNo).then((_) {
        _downloadGalleryImage(gallery, serialNo);
      });

      /// check if download task has been paused or removed
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }
    }
  }

  Future<void> pauseAllDownloadGallery() async {
    await Future.wait(gallerys.map((g) => pauseDownloadGallery(g)).toList());
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery, [bool shouldUpdate = true]) async {
    if (gid2downloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.switching) {
      return;
    }
    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.switching;
    if (shouldUpdate) {
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }

    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.paused);

    for (AsyncTask task in gid2Tasks[gallery.gid]!) {
      executor.cancelTask(task);
    }
    gid2Tasks[gallery.gid]!.clear();
    gid2CancelToken[gallery.gid]!.cancel();
    gid2SpeedComputer[gallery.gid]!.pause();

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.downloading) {
        image?.downloadStatus = DownloadStatus.paused;
        if (shouldUpdate) {
          update(['$imageId::${gallery.gid}']);
        }
      }
    }

    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.paused;
    if (shouldUpdate) {
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }
    Log.info('pause download gallery: ${gallery.gid}', false);
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    if (gid2downloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.switching) {
      return;
    }
    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.switching;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    /// avoid a immediate resume after pause
    // await Future.delayed(const Duration(milliseconds: 300));

    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloading);
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2SpeedComputer[gallery.gid]!.start();

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.paused) {
        image?.downloadStatus = DownloadStatus.downloading;
        update(['$imageId::${gallery.gid}']);
      }
    }

    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.downloading;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    Log.info('resume download gallery: ${gallery.gid}', false);
    downloadGallery(gallery, isFirstDownload: false);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery) async {
    await pauseDownloadGallery(gallery, false);
    await _clearGalleryDownloadInfoInDatabase(gallery.gid);
    await _clearDownloadedImageInDisk(gallery);
    _clearGalleryDownloadInfoInMemory(gallery);
    Log.info('delete download gallery: ${gallery.gid}', false);
  }

  /// use meta in each gallery folder to restore download status, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restore() async {
    io.Directory downloadDir = io.Directory(downloadPath);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    List<io.FileSystemEntity> galleryDirs = downloadDir.listSync();
    for (io.FileSystemEntity galleryDir in galleryDirs) {
      io.File metadataFile = io.File(path.join(galleryDir.path, _metadata));
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());
      GalleryDownloadedData gallery = GalleryDownloadedData.fromJson(metadata['gallery']);
      List<GalleryImage?> images = (jsonDecode(metadata['images']) as List)
          .map((_map) => _map == null ? null : GalleryImage.fromJson(_map))
          .toList();

      /// skip if exists
      if (gid2Images.containsKey(gallery.gid)) {
        continue;
      }

      int success = await _restoreDownloadInfoDatabase(gallery, images);
      if (success < 0) {
        Log.error('restore download failed. Gallery: ${gallery.title}');
        deleteGallery(gallery);
        continue;
      }
      _restoreDownloadInfoInMemory(gallery, images);
      restoredCount++;
    }

    return restoredCount;
  }

  Future<void> _parseGalleryImageHref(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    AsyncTask<List<GalleryThumbnail>> task = _parseGalleryImageHrefTask(gallery, serialNo);
    gid2Tasks[gallery.gid]!.add(task);

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await retry(
        () => executor.scheduleTask(serialNo * 100000, task),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.info('Parse image hrefs failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on CancelException catch (e) {
      return;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.info('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageHref(gallery, serialNo);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    int from = serialNo ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
    for (int i = 0; i < newThumbnails.length; i++) {
      gid2ImageHrefs[gallery.gid]![from + i] = newThumbnails[i];
    }
    update(['$imageId::${gallery.gid}', '$imageHrefsId::${gallery.gid}']);
    Log.verbose('parse image hrefs success', false);
  }

  AsyncTask<List<GalleryThumbnail>> _parseGalleryImageHrefTask(GalleryDownloadedData gallery, int serialNo) {
    return () {
      Log.verbose('begin to parse image hrefs', false);
      return EHRequest.requestDetailPage(
        galleryUrl: gallery.galleryUrl,
        thumbnailsPageNo: serialNo ~/ SiteSetting.thumbnailsCountPerPage.value,
        cancelToken: gid2CancelToken[gallery.gid],
        parser: EHSpiderParser.detailPage2Thumbnails,
      );
    };
  }

  Future<void> _parseGalleryImageUrl(GalleryDownloadedData gallery, int serialNo, [bool useCache = true]) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryImage image;
    AsyncTask<GalleryImage> task = _parseGalleryImageUrlTask(gallery, serialNo, useCache);
    gid2Tasks[gallery.gid]!.add(task);
    try {
      image = await retry(
        () => executor.scheduleTask(serialNo * 10000, task),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.info('ParseImageUrl failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on CancelException catch (e) {
      return;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.info('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        await pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageUrl(gallery, serialNo, useCache);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    gid2Images[gallery.gid]![serialNo] = image;
    image.path = _computeImageDownloadRelativePath(gallery, serialNo);
    image.downloadStatus = DownloadStatus.downloading;
    await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);
    Log.verbose('parse image url: $serialNo success', false);
  }

  AsyncTask<GalleryImage> _parseGalleryImageUrlTask(GalleryDownloadedData gallery, int serialNo,
      [bool useCache = true]) {
    return () {
      Log.verbose('begin to parse image url: $serialNo', false);
      return EHRequest.requestImagePage(
        gid2ImageHrefs[gallery.gid]![serialNo]!.href,
        cancelToken: gid2CancelToken[gallery.gid],
        useCacheIfAvailable: useCache,
        parser: EHSpiderParser.imagePage2GalleryImage,
      );
    };
  }

  Future<void> _downloadGalleryImage(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryImage image = gid2Images[gallery.gid]![serialNo]!;
    image.downloadStatus = DownloadStatus.downloading;
    update(['$imageId::${gallery.gid}', '$imageUrlId::${gallery.gid}::$serialNo']);

    AsyncTask<void> task = _downloadGalleryImageTask(gallery, serialNo, image.url);
    gid2Tasks[gallery.gid]!.add(task);
    try {
      await retry(
        () => executor.scheduleTask(serialNo, task),
        maxAttempts: retryTimes,
        retryIf: (e) =>
            e is DioError &&
            e.type != DioErrorType.cancel &&
            e.error is! EHException &&
            (e.response == null || e.response!.statusCode != 403),
        onRetry: (e) {
          Log.info(
            'DownloadImage: $serialNo failed, retry. Reason: ${(e as DioError).message}. Url:${gid2Images[gallery.gid]![serialNo]!.url}',
          );
          gid2SpeedComputer[gallery.gid]!.resetProgress(serialNo);
        },
      );
    } on CancelException catch (e) {
      return;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.info('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      Log.info(
        'downloadImage: $serialNo failed $retryTimes times, try re-parse. url:${gid2Images[gallery.gid]![serialNo]!.url}',
      );
      _reParseImageUrlAndDownload(gallery, serialNo);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    Log.verbose('download image: $serialNo success', false);

    GalleryDownloadProgress downloadProgress = gid2downloadProgress[gallery.gid]!;
    downloadProgress.curCount++;
    downloadProgress.hasDownloaded[serialNo] = true;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    image.downloadStatus = DownloadStatus.downloaded;
    await _updateImageDownloadStatusInDatabase(gid2Images[gallery.gid]![serialNo]!.url);
    update(['$imageId::${gallery.gid}', '$imageUrlId::${gallery.gid}::$serialNo']);

    /// all image has been downloaded
    if (downloadProgress.curCount == downloadProgress.totalCount) {
      downloadProgress.downloadStatus = DownloadStatus.downloaded;
      gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.downloaded.index);
      await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloaded);
      gid2SpeedComputer[gallery.gid]!.dispose();
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }

    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(gallery);
    }
  }

  AsyncTask<void> _downloadGalleryImageTask(GalleryDownloadedData gallery, int serialNo, String url) {
    return () {
      Log.verbose('begin to download image: $serialNo', false);
      return EHRequest.download(
        url: url,
        path: _computeImageDownloadAbsolutePath(gallery, serialNo),
        cancelToken: gid2CancelToken[gallery.gid],
        onReceiveProgress: (int count, int total) =>
            gid2SpeedComputer[gallery.gid]!.updateProgress(count, total, serialNo),
      );
    };
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo) async {
    await appDb.deleteImage(gid2Images[gallery.gid]![serialNo]!.url);
    if (gid2ImageHrefs[gallery.gid]?[serialNo] == null) {
      await _parseGalleryImageHref(gallery, serialNo);
    }
    await _parseGalleryImageUrl(gallery, serialNo, false);
    _downloadGalleryImage(gallery, serialNo);
  }

  String _computeGalleryDownloadPath(GalleryDownloadedData gallery) {
    return path.join(
      downloadPath,
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
    );
  }

  String _computeImageDownloadRelativePath(GalleryDownloadedData gallery, int serialNo) {
    return path.relative(
      path.join(
        downloadPath,
        '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
        '$serialNo.jpg',
      ),
      from: PathSetting.getVisibleDir().path,
    );
  }

  String _computeImageDownloadAbsolutePath(GalleryDownloadedData gallery, int serialNo) {
    return path.join(
      downloadPath,
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
      '$serialNo.jpg',
    );
  }

  /// init memory info
  void _initGalleryDownloadInfoInMemory(GalleryDownloadedData gallery, {bool insertAtFirst = true}) {
    if (insertAtFirst) {
      gallerys.insert(0, gallery);
    } else {
      gallerys.add(gallery);
    }
    gid2Tasks[gallery.gid] = [];
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2downloadProgress[gallery.gid] = GalleryDownloadProgress(totalCount: gallery.pageCount);
    gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2SpeedComputer[gallery.gid] = SpeedComputer(
      gallery.pageCount,
      () => update(['$speedComputerId::${gallery.gid}']),
    );
    update([downloadGallerysId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryDownloadInfoInMemory(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    gid2Tasks.remove(gallery.gid);
    gid2downloadProgress.remove(gallery.gid);
    gid2Images.remove(gallery.gid);
    gid2ImageHrefs.remove(gallery.gid);
    gid2SpeedComputer[gallery.gid]!.dispose();
    gid2SpeedComputer.remove(gallery.gid);
    update([downloadGallerysId]);
  }

  Future<void> _clearDownloadedImageInDisk(GalleryDownloadedData gallery) async {
    io.Directory directory = io.Directory(_computeGalleryDownloadPath(gallery));
    if (!directory.existsSync()) {
      return;
    }
    directory.deleteSync(recursive: true);
  }

  /// clear table row in database
  Future<void> _clearGalleryDownloadInfoInDatabase(int gid) {
    return appDb.transaction(() async {
      await appDb.deleteImagesWithGid(gid);
      await appDb.deleteGallery(gid);
    });
  }

  /// record a new download task
  Future<int> _saveNewGalleryDownloadInfoInDatabase(GalleryDownloadedData gallery) async {
    return await appDb.insertGallery(
      gallery.gid,
      gallery.token,
      gallery.title,
      gallery.category,
      gallery.pageCount,
      gallery.galleryUrl,
      gallery.uploader,
      gallery.publishTime,
      gallery.downloadStatusIndex,
      DateTime.now().toString(),
    );
  }

  void _saveGalleryDownloadInfoInDisk(GalleryDownloadedData gallery) {
    io.File file = io.File(path.join(_computeGalleryDownloadPath(gallery), _metadata));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    Map<String, Object> metadata = {
      'gallery': gallery.toJson(),
      'images': jsonEncode(gid2Images[gallery.gid]!),
    };

    file.writeAsStringSync(jsonEncode(metadata));
  }

  /// parse a image's url successfully, need to record its info and with its status beginning at 'downloading'
  Future<int> _saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) {
    return appDb.insertImage(
      image.url,
      serialNo,
      gid,
      image.height,
      image.width,
      image.path!,
      image.downloadStatus.index,
    );
  }

  /// update gallery status
  Future<int> _updateGalleryDownloadStatusInDatabase(int gid, DownloadStatus downloadStatus) {
    return appDb.updateGallery(downloadStatus.index, gid);
  }

  /// a image has been downloaded successfully, update its status
  Future<int> _updateImageDownloadStatusInDatabase(String url) {
    return appDb.updateImage(DownloadStatus.downloaded.index, url);
  }

  /// restore
  Future<int> _restoreDownloadInfoDatabase(GalleryDownloadedData gallery, List<GalleryImage?> images) async {
    if (gallery.downloadStatusIndex == DownloadStatus.downloading.index) {
      gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
    }

    int success = await _saveNewGalleryDownloadInfoInDatabase(gallery);
    if (success <= 0) {
      return success;
    }

    success = await appDb.transaction(() async {
      int serialNo = 0;
      Iterator iterator = images.iterator;
      while (iterator.moveNext()) {
        GalleryImage? image = iterator.current;
        if (image == null) {
          serialNo++;
          continue;
        }
        await _saveNewImageInfoInDatabase(image, serialNo++, gallery.gid);
      }

      return 1;
    }).catchError((_) => -1);

    return success;
  }

  /// restore
  void _restoreDownloadInfoInMemory(GalleryDownloadedData gallery, List<GalleryImage?> images) {
    gallerys.insert(0, gallery);
    gid2Tasks[gallery.gid] = [];
    gid2CancelToken[gallery.gid] = CancelToken();
    List<bool> hasDownloaded =
        images.map((image) => image?.downloadStatus == DownloadStatus.downloaded ? true : false).toList();
    gid2downloadProgress[gallery.gid] = GalleryDownloadProgress(
      downloadStatus: gallery.downloadStatusIndex == DownloadStatus.downloading.index
          ? DownloadStatus.paused
          : DownloadStatus.values[gallery.downloadStatusIndex],
      totalCount: gallery.pageCount,
      hasDownloaded: hasDownloaded,
    );
    gid2Images[gallery.gid] = images;
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2SpeedComputer[gallery.gid] = SpeedComputer(
      gallery.pageCount,
      () => update(['$speedComputerId::${gallery.gid}']),
    );
    update([downloadGallerysId]);
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) {
    return gid2downloadProgress[gallery.gid] == null ||
        gid2downloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.paused;
  }
}

/// compute gallery download speed during last period every second
class SpeedComputer {
  Timer? timer;

  String speed = '0 B/s';

  late List<int> imageDownloadedBytes;
  late List<int> imageTotalBytes;

  int allImageDownloadedBytesLastTime = 0;
  int allImageDownloadedBytes = 0;

  VoidCallback updateCallback;

  SpeedComputer(int pageCount, this.updateCallback)
      : imageDownloadedBytes = List.generate(pageCount, (index) => 0),
        imageTotalBytes = List.generate(pageCount, (index) => 1);

  void start() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int prevDownloadedBytesLast = allImageDownloadedBytesLastTime;
      allImageDownloadedBytesLastTime = allImageDownloadedBytes;

      double difference = 0.0 + allImageDownloadedBytes - prevDownloadedBytesLast;

      if (difference <= 0) {
        speed = '0 B/s';
        updateCallback.call();
        return;
      }

      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} B/s';
        updateCallback.call();
        return;
      }

      difference /= 1024;
      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} KB/s';
        updateCallback.call();
        return;
      }

      difference /= 1024;
      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} MB/s';
        updateCallback.call();
        return;
      }

      difference /= 1024;
      speed = '${difference.toStringAsFixed(2)} GB/s';
      updateCallback.call();
    });
  }

  void pause() {
    timer?.cancel();
    speed = '0 KB/s';
  }

  void updateProgress(int count, int total, int serialNo) {
    imageTotalBytes[serialNo] = total;
    allImageDownloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = count;
    allImageDownloadedBytes += count;
  }

  /// one image download failed
  void resetProgress(int serialNo) {
    allImageDownloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = 0;
  }

  void dispose() {
    timer?.cancel();
  }
}
