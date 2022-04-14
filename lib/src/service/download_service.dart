import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/database/database.dart';
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
import '../utils/eh_spider_parser.dart';

const String downloadGallerysId = 'downloadGallerysId';
const String imageId = 'imageId';
const String imageHrefsId = 'imageHrefsId';
const String imageUrlId = 'imageUrlId';
const String galleryDownloadProgressId = 'galleryDownloadProgressId';
const String speedComputerId = 'SpeedComputerId';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxController {
  final executor = Executor(concurrency: DownloadSetting.downloadTaskConcurrency.value);
  static const int retryTimes = 3;
  static const String _metadata = 'metadata';
  static final downloadPath = path.join(PathSetting.getVisibleDir().path, 'download');

  List<GalleryDownloadedData> gallerys = <GalleryDownloadedData>[];
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
  Future<void> downloadGallery(GalleryDownloadedData gallery,
      {bool isFirstDownload = true, ProgressCallback? onReceiveProgress, CancelToken? cancelToken}) async {
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

    /// Check if need resume
    if (gid2downloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.paused) {
      await resumeDownloadGallery(gallery);
    }

    for (int serialNo = 0; serialNo < gid2downloadProgress[gallery.gid]!.totalCount; serialNo++) {
      /// has downloaded this image
      if (gid2Images[gallery.gid]?[serialNo]?.downloadStatus == DownloadStatus.downloaded) {
        continue;
      }

      /// no parsed href, parse from thumbnails first
      if (gid2ImageHrefs[gallery.gid]?[serialNo] == null) {
        await _parseGalleryImageHref(gallery, serialNo);
      }

      /// no parsed url, parse from page first
      if (gid2Images[gallery.gid]?[serialNo] == null) {
        _parseGalleryImageUrl(gallery, serialNo).then((_) {
          _downloadGalleryImage(gallery, serialNo);
        });
      } else {
        _downloadGalleryImage(gallery, serialNo);
      }

      /// check if download task has been paused or removed
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }
    }
  }

  Future<void> pauseAllDownloadGallery() async {
    await Future.wait(gallerys.map((g) => pauseDownloadGallery(g)).toList());
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.paused);
    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.paused;
    gid2CancelToken[gallery.gid]!.cancel();
    gid2SpeedComputer[gallery.gid]!.pause();
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.downloading) {
        image?.downloadStatus = DownloadStatus.paused;
        update(['$imageId::${gallery.gid}']);
      }
    }

    Log.info('pause download gallery: ${gallery.gid}', false);
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloading);
    gid2downloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.downloading;
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2SpeedComputer[gallery.gid]!.start();
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.paused) {
        image?.downloadStatus = DownloadStatus.downloading;
        update(['$imageId::${gallery.gid}']);
      }
    }

    Log.info('resume download gallery: ${gallery.gid}', false);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery) async {
    await pauseDownloadGallery(gallery);
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
        deleteGallery(gallery);
        continue;
      }
      _restoreDownloadInfoInMemory(gallery, images);
      restoredCount++;
    }

    return restoredCount;
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) {
    return gid2downloadProgress[gallery.gid] == null ||
        gid2downloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.paused;
  }

  Future<void> _parseGalleryImageHref(GalleryDownloadedData gallery, int serialNo) async {
    List<GalleryThumbnail> newThumbnails;

    try {
      List<GalleryThumbnail>? result = await retry(
        () => executor.scheduleTask(
          () {
            if (_taskHasBeenPausedOrRemoved(gallery)) {
              return null;
            }
            return EHRequest.requestDetailPage(
              galleryUrl: gallery.galleryUrl,
              thumbnailsPageNo: serialNo ~/ SiteSetting.thumbnailsCountPerPage.value,
              cancelToken: gid2CancelToken[gallery.gid],
              parser: EHSpiderParser.detailPage2Thumbnails,
            );
          },
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.error('parse image hrefs failed, retry', (e as DioError).message),
        maxAttempts: retryTimes,
      );

      if (result == null) {
        return;
      }
      newThumbnails = result;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageHref(gallery, serialNo);
      return;
    }

    int from = serialNo ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
    for (int i = 0; i < newThumbnails.length; i++) {
      gid2ImageHrefs[gallery.gid]![from + i] = newThumbnails[i];
    }
    update(['$imageId::${gallery.gid}', '$imageHrefsId::${gallery.gid}']);
    Log.verbose('parse image hrefs success', false);
  }

  Future<void> _parseGalleryImageUrl(GalleryDownloadedData gallery, int serialNo, [bool useCache = true]) async {
    GalleryImage image;

    try {
      GalleryImage? result = await retry(
        () => executor.scheduleTask(
          () {
            if (_taskHasBeenPausedOrRemoved(gallery)) {
              return null;
            }
            return EHRequest.requestImagePage(
              gid2ImageHrefs[gallery.gid]![serialNo]!.href,
              cancelToken: gid2CancelToken[gallery.gid],
              useCacheIfAvailable: useCache,
              parser: EHSpiderParser.imagePage2GalleryImage,
            );
          },
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.error('parseImageUrl failed, retry', (e as DioError).message),
        maxAttempts: retryTimes,
      );
      if (result == null) {
        return;
      }
      image = result;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        await pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageUrl(gallery, serialNo, useCache);
      return;
    }

    gid2Images[gallery.gid]![serialNo] = image;
    image.path = _computeImageDownloadRelativePath(gallery, serialNo);
    image.downloadStatus = DownloadStatus.downloading;
    await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);
    Log.verbose('parse image url: $serialNo success', false);
  }

  Future<void> _downloadGalleryImage(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryImage image = gid2Images[gallery.gid]![serialNo]!;

    image.downloadStatus = DownloadStatus.downloading;
    update(['$imageId::${gallery.gid}', '$imageUrlId::${gallery.gid}::$serialNo']);

    Log.verbose('begin to download image: $serialNo', false);
    try {
      dynamic result = await retry(
        () => executor.scheduleTask(
          () {
            if (_taskHasBeenPausedOrRemoved(gallery)) {
              return null;
            }
            return EHRequest.download(
              url: image.url,
              path: _computeImageDownloadAbsolutePath(gallery, serialNo),
              cancelToken: gid2CancelToken[gallery.gid],
              onReceiveProgress: (int count, int total) =>
                  gid2SpeedComputer[gallery.gid]!.updateProgress(count, total, serialNo),
            );
          },
        ),
        maxAttempts: retryTimes,
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) {
          Log.error(
            'downloadImage: $serialNo failed, retry. url:${gid2Images[gallery.gid]![serialNo]!.url}',
            (e as DioError).message,
          );
          gid2SpeedComputer[gallery.gid]!.resetProgress(serialNo);
        },
      );
      if (result == null) {
        return;
      }
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      Log.error(
        'downloadImage: $serialNo failed $retryTimes times, try re-parse. url:${gid2Images[gallery.gid]![serialNo]!.url}',
      );
      _reParseImageUrlAndDownload(gallery, serialNo);
      return;
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
      await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloaded);
      gid2SpeedComputer[gallery.gid]!.dispose();
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }

    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(gallery);
    }
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo) async {
    await appDb.deleteImage(gid2Images[gallery.gid]![serialNo]!.url);
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
    gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
    int success = await _saveNewGalleryDownloadInfoInDatabase(gallery);
    if (success <= 0) {
      return success;
    }

    List<int> successes = await Future.wait(
      images.mapIndexed((index, image) {
        if (image == null) {
          return Future.value(1);
        }
        return _saveNewImageInfoInDatabase(image, index, gallery.gid);
      }).toList(),
    );

    return successes.any((e) => e <= 0) ? -1 : 1;
  }

  /// restore
  void _restoreDownloadInfoInMemory(GalleryDownloadedData gallery, List<GalleryImage?> images) {
    gallerys.insert(0, gallery);
    gid2CancelToken[gallery.gid] = CancelToken();
    List<bool> hasDownloaded =
        images.map((image) => image?.downloadStatus == DownloadStatus.downloaded ? true : false).toList();
    gid2downloadProgress[gallery.gid] = GalleryDownloadProgress(
      downloadStatus: DownloadStatus.paused,
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
        return;
      }
      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} B/s';
        return;
      }
      difference /= 1024;
      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} KB/s';
        return;
      }
      difference /= 1024;
      if (difference < 1024) {
        speed = '${difference.toStringAsFixed(2)} MB/s';
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
