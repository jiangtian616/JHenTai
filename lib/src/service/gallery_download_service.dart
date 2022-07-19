import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/cancel_exception.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
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
const String galleryDownloadSpeedComputerId = 'galleryDownloadSpeedComputerId';

/// responsible for local images meta-data and download all images of a gallery
class GalleryDownloadService extends GetxController {
  final executor = EHExecutor(
    concurrency: DownloadSetting.downloadTaskConcurrency.value,
    rate: Rate(DownloadSetting.maximum.value, DownloadSetting.period.value),
  );
  static const int retryTimes = 3;
  static const String _metadata = '.metadata';
  static const int _maxTitleLength = 100;

  List<GalleryDownloadedData> gallerys = <GalleryDownloadedData>[];
  Map<int, int> gid2ThumbnailsCountPerPage = {};
  Map<int, List<AsyncTask>> gid2Tasks = {};
  Map<int, CancelToken> gid2CancelToken = {};
  Map<int, GalleryDownloadProgress> gid2DownloadProgress = <int, GalleryDownloadProgress>{};
  Map<int, List<GalleryThumbnail?>> gid2ImageHrefs = {};
  Map<int, List<GalleryImage?>> gid2Images = <int, List<GalleryImage?>>{};
  Map<int, GalleryDownloadSpeedComputer> gid2SpeedComputer = {};

  static Future<void> init() async {
    ensureDownloadDirExists();
    Get.put(GalleryDownloadService(), permanent: true);
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
        oldVersionGalleryUrl: result.oldVersionGalleryUrl,
        uploader: result.uploader,
        publishTime: result.publishTime,
        downloadStatusIndex: result.galleryDownloadStatusIndex,
        insertTime: result.insertTime,
      );

      if (gallerys.isEmpty || gallerys.last.gid != gallery.gid) {
        _initGalleryDownloadInfoInMemory(gallery, insertAtFirst: false);
        gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.values[result.galleryDownloadStatusIndex];
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
        imageHash: result.imageHash,
        downloadStatus: DownloadStatus.values[result.imageDownloadStatusIndex!],
      );
      gid2Images[gallery.gid]![result.serialNo!] = image;

      if (image.downloadStatus == DownloadStatus.downloaded) {
        gid2DownloadProgress[gallery.gid]!.curCount++;
        gid2DownloadProgress[gallery.gid]!.hasDownloaded[result.serialNo!] = true;
      }
    }

    /// resume if status is [downloading]
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        gid2SpeedComputer[g.gid]!.start();
        downloadGallery(g, isFirstDownload: false);
      }
    }

    Log.verbose('init DownloadService success, download task count: ${gallerys.length}');
    super.onInit();
  }

  /// begin to download all images of a gallery
  /// step 1: get image href from its thumbnail, if thumbnail haven't been parsed, parse thumbnail first.
  /// step 2: get image url by parsing page (with href parsed last step)
  /// step 3: download image
  Future<void> downloadGallery(GalleryDownloadedData gallery, {bool isFirstDownload = true}) async {
    if (isFirstDownload && gid2DownloadProgress.containsKey(gallery.gid)) {
      return;
    }

    Log.info('begin to download gallery: ${gallery.gid}');

    ensureDownloadDirExists();

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

    for (int serialNo = 0; serialNo < gid2DownloadProgress[gallery.gid]!.totalCount; serialNo++) {
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

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    if (gid2DownloadProgress[gallery.gid]!.downloadStatus != DownloadStatus.downloading) {
      return;
    }
    gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.switching;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.paused);
    gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.paused;

    for (AsyncTask task in gid2Tasks[gallery.gid]!) {
      executor.cancelTask(task);
    }
    gid2Tasks[gallery.gid]!.clear();
    gid2CancelToken[gallery.gid]!.cancel();
    gid2SpeedComputer[gallery.gid]!.pause();

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.downloading) {
        image?.downloadStatus = DownloadStatus.paused;
        update(['$imageId::${gallery.gid}']);
      }
    }

    update(['$galleryDownloadProgressId::${gallery.gid}']);
    Log.info('pause download gallery: ${gallery.gid}');
  }

  Future<void> resumeAllDownloadGallery() async {
    await Future.wait(gallerys.map((g) => resumeDownloadGallery(g)).toList());
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    if (gid2DownloadProgress[gallery.gid]!.downloadStatus != DownloadStatus.paused) {
      return;
    }
    gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.switching;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloading);
    gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.downloading;
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2SpeedComputer[gallery.gid]!.start();

    for (GalleryImage? image in gid2Images[gallery.gid]!) {
      if (image?.downloadStatus == DownloadStatus.paused) {
        image?.downloadStatus = DownloadStatus.downloading;
        update(['$imageId::${gallery.gid}']);
      }
    }

    update(['$galleryDownloadProgressId::${gallery.gid}']);

    Log.info('resume download gallery: ${gallery.gid}');
    downloadGallery(gallery, isFirstDownload: false);
  }

  /// Update local downloaded gallery if there's a new version.
  Future<void> updateGallery(GalleryDownloadedData oldGallery, String newVersionGalleryUrl) async {
    GalleryDownloadedData newGallery;
    try {
      Gallery gallery = await retry(
        () => EHRequest.requestDetailPage(
          galleryUrl: newVersionGalleryUrl,
          parser: EHSpiderParser.detailPage2Gallery,
        ),
        retryIf: (e) => e is DioError && e.error is! EHException,
        maxAttempts: retryTimes,
      );
      newGallery = gallery.toGalleryDownloadedData();
    } on DioError catch (e) {
      if (e.error is EHException) {
        Log.info('${'updateGalleryError'.tr}, reason: ${e.error.msg}');
        snack('updateGalleryError'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      return await updateGallery(oldGallery, newVersionGalleryUrl);
    }

    newGallery = newGallery.copyWith(oldVersionGalleryUrl: oldGallery.galleryUrl);
    downloadGallery(newGallery);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery) async {
    await pauseDownloadGallery(gallery);
    await _clearGalleryDownloadInfoInDatabase(gallery.gid);
    await _clearDownloadedImageInDisk(gallery);
    _clearGalleryDownloadInfoInMemory(gallery);

    update(['$galleryDownloadProgressId::${gallery.gid}']);
    Log.info('delete download gallery: ${gallery.gid}');
  }

  Future<void> updateImagePathAfterDownloadPathChanged() async {
    await appDb.transaction(() async {
      for (GalleryDownloadedData gallery in gallerys) {
        for (int serialNo = 0; serialNo < gid2Images[gallery.gid]!.length; serialNo++) {
          if (gid2Images[gallery.gid]![serialNo] == null) {
            continue;
          }
          String newPath = _computeImageDownloadRelativePath(gallery, serialNo);

          await appDb.updateImagePath(newPath, gallery.gid, gid2Images[gallery.gid]![serialNo]!.url);
          gid2Images[gallery.gid]![serialNo]!.path = newPath;

          update(['$imageId::${gallery.gid}', '$imageUrlId::${gallery.gid}::$serialNo']);
        }
      }
    });
  }

  /// use meta in each gallery folder to restore download status, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restore() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
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
      List<GalleryImage?> images = (jsonDecode(metadata['images']) as List).map((_map) => _map == null ? null : GalleryImage.fromJson(_map)).toList();

      /// skip if exists
      if (gid2Images.containsKey(gallery.gid)) {
        continue;
      }

      /// To be compatible with the previous version, check current download path.
      for (int serialNo = 0; serialNo < images.length; serialNo++) {
        if (images[serialNo] == null) {
          continue;
        }
        String newPath = _computeImageDownloadRelativePath(gallery, serialNo, image: images[serialNo]!);
        images[serialNo]!.path = newPath;
      }

      /// For some reason, downloadStatusIndex is not updated correctly.
      if (gallery.downloadStatusIndex != DownloadStatus.downloaded.index) {
        int downloadedImageCount = images.fold(
          0,
          (previousValue, element) => previousValue + (element?.downloadStatus == DownloadStatus.downloaded ? 1 : 0),
        );
        if (downloadedImageCount == gallery.pageCount) {
          gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.downloaded.index);
        }
      }

      int success = await _restoreDownloadInfoDatabase(gallery, images);
      if (success < 0) {
        Log.error('restore download failed. Gallery: ${gallery.title}');
        _clearGalleryDownloadInfoInDatabase(gallery.gid);
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

    AsyncTask<List<GalleryThumbnail>> task = _parseGalleryImageHrefTask(gallery, serialNo ~/ gid2ThumbnailsCountPerPage[gallery.gid]!);
    gid2Tasks[gallery.gid]!.add(task);

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await retry(
        () => executor.scheduleTask(serialNo * 100000, task),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.download('Parse image hrefs failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on CancelException catch (e) {
      return;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.download('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageHref(gallery, serialNo);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    gid2ThumbnailsCountPerPage[gallery.gid] = (newThumbnails.length / 20).ceil() * 20;

    int from = serialNo ~/ gid2ThumbnailsCountPerPage[gallery.gid]! * gid2ThumbnailsCountPerPage[gallery.gid]!;
    for (int i = 0; i < newThumbnails.length; i++) {
      gid2ImageHrefs[gallery.gid]![from + i] = newThumbnails[i];
    }
    update(['$imageId::${gallery.gid}', '$imageHrefsId::${gallery.gid}']);
    Log.download('parse image hrefs success');

    /// some gallery's [thumbnailsCountPerPage] is not equal to default setting
    if (gid2ImageHrefs[gallery.gid]![serialNo] == null) {
      await _parseGalleryImageHref(gallery, serialNo);
    }
  }

  AsyncTask<List<GalleryThumbnail>> _parseGalleryImageHrefTask(GalleryDownloadedData gallery, int thumbnailsPageNo) {
    return () {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        throw CancelException();
      }
      Log.download('begin to parse image hrefs');
      return EHRequest.requestDetailPage(
        galleryUrl: gallery.galleryUrl,
        thumbnailsPageNo: thumbnailsPageNo,
        cancelToken: gid2CancelToken[gallery.gid],
        parser: EHSpiderParser.detailPage2Thumbnails,
      );
    };
  }

  Future<void> _parseGalleryImageUrl(GalleryDownloadedData gallery, int serialNo, {bool useCache = true}) async {
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
        onRetry: (e) => Log.download('ParseImageUrl failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on CancelException catch (e) {
      return;
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.download('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        await pauseAllDownloadGallery();
        return;
      }
      await _parseGalleryImageUrl(gallery, serialNo, useCache: useCache);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    gid2Images[gallery.gid]![serialNo] = image;
    image.path = _computeImageDownloadRelativePath(gallery, serialNo);
    image.downloadStatus = DownloadStatus.downloading;
    await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);
    Log.download('parse image url: $serialNo success');
  }

  AsyncTask<GalleryImage> _parseGalleryImageUrlTask(GalleryDownloadedData gallery, int serialNo, [bool useCache = true]) {
    return () {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        throw CancelException();
      }
      Log.download('begin to parse image url: $serialNo');
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
    _updateImageDownloadStatus(image, gallery.gid, serialNo, DownloadStatus.downloading);

    /// update from old gallery
    if (gallery.oldVersionGalleryUrl != null) {
      await _tryCopyImageInfo(gallery, gallery.oldVersionGalleryUrl!, serialNo);
      if (gid2Images[gallery.gid]![serialNo]!.downloadStatus == DownloadStatus.downloaded) {
        return;
      }
    }

    AsyncTask<void> task = _downloadGalleryImageTask(gallery, serialNo, image.url);
    gid2Tasks[gallery.gid]!.add(task);
    try {
      await retry(
        () => executor.scheduleTask(serialNo, task),
        maxAttempts: retryTimes,
        retryIf: (e) =>
            e is DioError && e.type != DioErrorType.cancel && e.error is! EHException && (e.response == null || e.response!.statusCode != 403),
        onRetry: (e) {
          Log.download(
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
        Log.download('Download Error, reason: ${e.error.msg}');
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      Log.download(
        'downloadImage: $serialNo failed $retryTimes times, try re-parse. url:${gid2Images[gallery.gid]![serialNo]!.url}',
      );
      _reParseImageUrlAndDownload(gallery, serialNo);
      return;
    } finally {
      gid2Tasks[gallery.gid]?.remove(task);
    }

    Log.download('download image: $serialNo success');

    await _updateImageDownloadStatus(image, gallery.gid, serialNo, DownloadStatus.downloaded);
    _updateProgressAfterImageDownloaded(gallery.gid, serialNo);
  }

  AsyncTask<void> _downloadGalleryImageTask(GalleryDownloadedData gallery, int serialNo, String url) {
    return () {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        throw CancelException();
      }
      Log.download('begin to download image: $serialNo');
      return EHRequest.download(
        url: url,
        path: _computeImageDownloadAbsolutePath(gallery, serialNo),
        cancelToken: gid2CancelToken[gallery.gid],
        onReceiveProgress: (int count, int total) => gid2SpeedComputer[gallery.gid]!.updateProgress(count, total, serialNo),
      );
    };
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo) async {
    await appDb.deleteImage(gallery.gid, gid2Images[gallery.gid]![serialNo]!.url);
    if (gid2ImageHrefs[gallery.gid]?[serialNo] == null) {
      await _parseGalleryImageHref(gallery, serialNo);
    }
    await _parseGalleryImageUrl(gallery, serialNo, useCache: false);
    _downloadGalleryImage(gallery, serialNo);
  }

  String _computeGalleryDownloadPath(GalleryDownloadedData gallery) {
    String title = gallery.title.replaceAll(RegExp(r'[/|?,:*"<>]'), ' ').trim();
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trim();
    }
    return path.join(
      DownloadSetting.downloadPath.value,
      '${gallery.gid} - $title',
    );
  }

  String _computeImageDownloadRelativePath(GalleryDownloadedData gallery, int serialNo, {GalleryImage? image}) {
    image ??= gid2Images[gallery.gid]![serialNo]!;
    String ext = image.url.split('.').last;
    String title = gallery.title.replaceAll(RegExp(r'[/|?,:*"<>]'), ' ').trim();
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trim();
    }

    return path.relative(
      path.join(
        DownloadSetting.downloadPath.value,
        '${gallery.gid} - $title',
        '$serialNo.$ext',
      ),
      from: PathSetting.getVisibleDir().path,
    );
  }

  String _computeImageDownloadAbsolutePath(GalleryDownloadedData gallery, int serialNo) {
    GalleryImage image = gid2Images[gallery.gid]![serialNo]!;
    String ext = image.url.split('.').last;
    String title = gallery.title.replaceAll(RegExp(r'[/|?,:*"<>]'), ' ').trim();
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trim();
    }

    return path.join(
      DownloadSetting.downloadPath.value,
      '${gallery.gid} - $title',
      '$serialNo.$ext',
    );
  }

  Future<void> _tryCopyImageInfo(GalleryDownloadedData newGallery, String oldVersionGalleryUrl, int newImageSerialNo) async {
    GalleryDownloadedData? oldGallery = gallerys.firstWhereOrNull((e) => e.galleryUrl == oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    String newImageHash = gid2Images[newGallery.gid]![newImageSerialNo]!.imageHash!;
    GalleryImage? oldImage = gid2Images[oldGallery.gid]!.firstWhereOrNull((e) => e?.imageHash == newImageHash);
    if (oldImage == null) {
      return;
    }

    await _copyImageInfo(newGallery, newImageSerialNo, oldImage);
  }

  Future<void> _copyImageInfo(GalleryDownloadedData newGallery, int newImageSerialNo, GalleryImage oldImage) async {
    Log.download('copy old image, serialNo: $newImageSerialNo');

    GalleryImage newImage = gid2Images[newGallery.gid]![newImageSerialNo]!;

    io.File file = io.File(path.join(PathSetting.getVisibleDir().path, oldImage.path!));
    file.copySync(path.join(PathSetting.getVisibleDir().path, newImage.path!));

    await _updateImageDownloadStatus(newImage, newGallery.gid, newImageSerialNo, DownloadStatus.downloaded);
    _updateProgressAfterImageDownloaded(newGallery.gid, newImageSerialNo);
  }

  void _initGalleryDownloadInfoInMemory(GalleryDownloadedData gallery, {bool insertAtFirst = true}) {
    if (insertAtFirst) {
      gallerys.insert(0, gallery);
    } else {
      gallerys.add(gallery);
    }
    gid2ThumbnailsCountPerPage[gallery.gid] = SiteSetting.thumbnailsCountPerPage.value;
    gid2Tasks[gallery.gid] = [];
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2DownloadProgress[gallery.gid] = GalleryDownloadProgress(
      totalCount: gallery.pageCount,
      downloadStatus: DownloadStatus.values[gallery.downloadStatusIndex],
    );
    gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2SpeedComputer[gallery.gid] = GalleryDownloadSpeedComputer(
      gallery.pageCount,
      () => update(['$galleryDownloadSpeedComputerId::${gallery.gid}']),
    );
    update([downloadGallerysId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryDownloadInfoInMemory(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    gid2ThumbnailsCountPerPage.remove(gallery.gid);
    gid2Tasks.remove(gallery.gid);
    gid2DownloadProgress.remove(gallery.gid);
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

  Future<void> _clearGalleryDownloadInfoInDatabase(int gid) {
    return appDb.transaction(() async {
      await appDb.deleteImagesWithGid(gid);
      await appDb.deleteGallery(gid);
    });
  }

  Future<int> _saveNewGalleryDownloadInfoInDatabase(GalleryDownloadedData gallery) async {
    return await appDb.insertGallery(
      gallery.gid,
      gallery.token,
      gallery.title,
      gallery.category,
      gallery.pageCount,
      gallery.galleryUrl,
      gallery.oldVersionGalleryUrl,
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
      image.imageHash!,
      image.downloadStatus.index,
    );
  }

  Future<void> _updateGalleryDownloadStatus(GalleryDownloadedData gallery) async {
    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.values[gallery.downloadStatusIndex]);
    gallerys[gallerys.indexWhere((e) => e.gid == gallery.gid)] = gallery;
    gid2DownloadProgress[gallery.gid]!.downloadStatus = DownloadStatus.values[gallery.downloadStatusIndex];
    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(gallery);
    }
    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  /// update gallery status
  Future<int> _updateGalleryDownloadStatusInDatabase(int gid, DownloadStatus downloadStatus) {
    return appDb.updateGallery(downloadStatus.index, gid);
  }

  Future<void> _updateImageDownloadStatus(GalleryImage image, int gid, int serialNo, DownloadStatus downloadStatus) async {
    await _updateImageDownloadStatusInDatabase(gid, image.url, downloadStatus);

    image.downloadStatus = downloadStatus;
    update(['$imageId::$gid', '$imageUrlId::$gid::$serialNo']);

    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(gallerys.firstWhere((e) => e.gid == gid));
    }
  }

  /// a image has been downloaded successfully, update its status
  Future<int> _updateImageDownloadStatusInDatabase(int gid, String url, DownloadStatus downloadStatus) {
    return appDb.updateImageStatus(downloadStatus.index, gid, url);
  }

  Future<void> _updateProgressAfterImageDownloaded(int gid, int serialNo) async {
    GalleryDownloadProgress downloadProgress = gid2DownloadProgress[gid]!;
    downloadProgress.curCount++;
    downloadProgress.hasDownloaded[serialNo] = true;

    if (downloadProgress.curCount == downloadProgress.totalCount) {
      downloadProgress.downloadStatus = DownloadStatus.downloaded;
      await _updateGalleryDownloadStatus(gallerys.firstWhere((e) => e.gid == gid).copyWith(downloadStatusIndex: DownloadStatus.downloaded.index));
      gid2SpeedComputer[gid]!.dispose();
    }

    update(['$galleryDownloadProgressId::$gid']);
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
    gid2ThumbnailsCountPerPage[gallery.gid] = SiteSetting.thumbnailsCountPerPage.value;
    gid2Tasks[gallery.gid] = [];
    gid2CancelToken[gallery.gid] = CancelToken();
    List<bool> hasDownloaded = images.map((image) => image?.downloadStatus == DownloadStatus.downloaded ? true : false).toList();
    gid2DownloadProgress[gallery.gid] = GalleryDownloadProgress(
      downloadStatus: gallery.downloadStatusIndex == DownloadStatus.downloading.index
          ? DownloadStatus.paused
          : DownloadStatus.values[gallery.downloadStatusIndex],
      totalCount: gallery.pageCount,
      hasDownloaded: hasDownloaded,
    );
    gid2Images[gallery.gid] = images;
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
    gid2SpeedComputer[gallery.gid] = GalleryDownloadSpeedComputer(
      gallery.pageCount,
      () => update(['$galleryDownloadSpeedComputerId::${gallery.gid}']),
    );
    update([downloadGallerysId]);
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) {
    return gid2DownloadProgress[gallery.gid] == null || gid2DownloadProgress[gallery.gid]!.downloadStatus == DownloadStatus.paused;
  }

  static void ensureDownloadDirExists() {
    io.Directory(DownloadSetting.downloadPath.value).createSync(recursive: true);
  }
}

/// compute gallery download speed during last period every second
class GalleryDownloadSpeedComputer extends SpeedComputer {
  late List<int> imageDownloadedBytes;
  late List<int> imageBytes;

  GalleryDownloadSpeedComputer(int pageCount, VoidCallback updateCallback)
      : imageDownloadedBytes = List.generate(pageCount, (index) => 0),
        imageBytes = List.generate(pageCount, (index) => 1),
        super(updateCallback: updateCallback);

  void updateProgress(int count, int total, int serialNo) {
    imageBytes[serialNo] = total;
    downloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = count;
    downloadedBytes += imageDownloadedBytes[serialNo];
  }

  /// one image download failed
  void resetProgress(int serialNo) {
    downloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = 0;
  }
}
