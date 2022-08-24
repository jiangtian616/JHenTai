import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:flutter/material.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:get/state_manager.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/service/check_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

import '../exception/cancel_exception.dart';
import '../exception/eh_exception.dart';
import '../model/gallery.dart';
import '../model/gallery_image.dart';
import '../network/eh_cookie_manager.dart';
import '../network/eh_request.dart';
import '../setting/path_setting.dart';
import '../utils/eh_executor.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/snack_util.dart';

const String initGalleryId = 'initGalleryId';
const String removeGalleryId = 'removeGalleryId';
const String galleryCountChangedId = 'galleryCountChangedId';
const String downloadImageId = 'downloadImageId';
const String downloadImageUrlId = 'downloadImageUrlId';
const String galleryDownloadProgressId = 'galleryDownloadProgressId';
const String galleryDownloadSpeedComputerId = 'galleryDownloadSpeedComputerId';

/// Responsible for local images meta-data and download all images of a gallery
class GalleryDownloadService extends GetxController {
  late EHExecutor executor;

  List<GalleryDownloadedData> gallerys = [];
  Map<int, GalleryDownloadInfo> galleryDownloadInfos = {};

  static const int _retryTimes = 3;
  static const String _metadata = '.metadata';
  static const int _maxTitleLength = 100;

  static const int _defaultDownloadGalleryPriority = -1;
  static const int _downloadGalleryPriorityBase = 10000;

  static Future<void> init() async {
    Get.put(GalleryDownloadService(), permanent: true);
  }

  @override
  onInit() async {
    await _instantiateFromDB();

    Log.info('Init DownloadService success, download task count: ${gallerys.length}');

    _startExecutor();

    super.onInit();
  }

  Future<void> rebootExecutor() async {
    await _shutdownExecutor();
    _startExecutor();
  }

  Future<void> downloadGallery(GalleryDownloadedData gallery, {bool resume = false}) async {
    if (!resume && galleryDownloadInfos.containsKey(gallery.gid)) {
      return;
    }

    _ensureDownloadDirExists();

    /// If it's a new download task, record info.
    if (!resume && !await _initGalleryInfo(gallery)) {
      return;
    }

    galleryDownloadInfos[gallery.gid]!.speedComputer.start();

    Log.info('Begin to download gallery: ${gallery.gid}, original: ${gallery.downloadOriginalImage}');

    _submitTask(
      gid: gallery.gid,
      priority: _computeDownloadPriority(gallery.insertTime),
      task: _downloadGalleryTask(gallery),
    );
  }

  Future<void> pauseAllDownloadGallery() async {
    await Future.wait(gallerys.map((g) => pauseDownloadGallery(g)).toList());
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
    GalleryDownloadProgress downloadProgress = galleryDownloadInfo.downloadProgress;

    if (downloadProgress.downloadStatus != DownloadStatus.downloading) {
      return;
    }

    if (!await _updateGalleryStatusInDatabase(gallery.gid, DownloadStatus.paused)) {
      return;
    }

    downloadProgress.downloadStatus = DownloadStatus.paused;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    for (AsyncTask task in galleryDownloadInfo.tasks) {
      executor.cancelTask(task);
    }

    galleryDownloadInfo.tasks.clear();
    galleryDownloadInfo.cancelToken.cancel();
    galleryDownloadInfo.speedComputer.pause();

    for (GalleryImage? image in galleryDownloadInfo.images) {
      /// no need to update db
      if (image?.downloadStatus == DownloadStatus.downloading) {
        image?.downloadStatus = DownloadStatus.paused;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    Log.info('Pause download gallery: ${gallery.title}');
  }

  Future<void> resumeAllDownloadGallery() async {
    /// order by insert time
    await Future.wait(gallerys.reversed.map((g) => resumeDownloadGallery(g)).toList());
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
    GalleryDownloadProgress downloadProgress = galleryDownloadInfo.downloadProgress;

    if (downloadProgress.downloadStatus != DownloadStatus.paused) {
      return;
    }

    if (!await _updateGalleryStatusInDatabase(gallery.gid, DownloadStatus.downloading)) {
      return;
    }

    downloadProgress.downloadStatus = DownloadStatus.downloading;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    /// can't reuse
    galleryDownloadInfo.cancelToken = CancelToken();
    galleryDownloadInfo.speedComputer.start();

    for (GalleryImage? image in galleryDownloadInfo.images) {
      /// no need to update db
      if (image?.downloadStatus == DownloadStatus.paused) {
        image?.downloadStatus = DownloadStatus.downloading;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    Log.info('Resume download gallery: ${gallery.title}');

    downloadGallery(gallery, resume: true);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery, {bool deleteImages = true}) async {
    await pauseDownloadGallery(gallery);

    Log.info('Delete download gallery: ${gallery.title}');

    await _clearGalleryDownloadInfoInDatabase(gallery.gid);
    if (deleteImages) {
      _clearDownloadedImageInDisk(gallery);
    }
    _clearGalleryInfoInMemory(gallery);

    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  /// Update local downloaded gallery if there's a new version.
  Future<void> updateGallery(GalleryDownloadedData oldGallery, String newVersionGalleryUrl) async {
    Log.info('ReDownload gallery: ${oldGallery.title}');

    GalleryDownloadedData newGallery;
    try {
      Gallery gallery = await retry(
        () => EHRequest.requestDetailPage(galleryUrl: newVersionGalleryUrl, parser: EHSpiderParser.detailPage2Gallery),
        retryIf: (e) => e is DioError && e.error is! EHException,
        maxAttempts: _retryTimes,
      );
      newGallery = gallery.toGalleryDownloadedData(downloadOriginalImage: oldGallery.downloadOriginalImage);
    } on DioError catch (e) {
      if (e.error is EHException) {
        Log.info('${'updateGalleryError'.tr}, reason: ${e.error.msg}');
        snack('updateGalleryError'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
      }
      return;
    }

    newGallery = newGallery.copyWith(oldVersionGalleryUrl: oldGallery.galleryUrl);

    downloadGallery(newGallery);
  }

  Future<void> reDownloadGallery(GalleryDownloadedData gallery) async {
    Log.info('Re-download gallery: ${gallery.gid}');

    await deleteGallery(gallery);

    downloadGallery(gallery.copyWith(downloadStatusIndex: DownloadStatus.downloading.index, insertTime: null));

    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  /// Use meta in each gallery folder to restore download status, then sync to database.
  /// This is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    for (io.FileSystemEntity galleryDir in downloadDir.listSync()) {
      io.File metadataFile = io.File(path.join(galleryDir.path, _metadata));

      /// metadata file does not exist
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());

      /// compatible with new field
      (metadata['gallery'] as Map).putIfAbsent('downloadOriginalImage', () => false);

      GalleryDownloadedData gallery = GalleryDownloadedData.fromJson(metadata['gallery']);
      List<GalleryImage?> images = (jsonDecode(metadata['images']) as List).map((_map) => _map == null ? null : GalleryImage.fromJson(_map)).toList();

      /// skip if exists
      if (galleryDownloadInfos.containsKey(gallery.gid)) {
        continue;
      }

      /// To deal with changed download location, compute download path again.
      for (int serialNo = 0; serialNo < images.length; serialNo++) {
        if (images[serialNo] == null) {
          continue;
        }
        images[serialNo]!.path = _computeImageDownloadRelativePath(gallery.title, gallery.gid, images[serialNo]!.url, serialNo);
      }

      /// For some reason, downloaded status is not updated correctly, check it again
      if (gallery.downloadStatusIndex != DownloadStatus.downloaded.index) {
        int downloadedImageCount = images.fold(0, (total, image) => total + (image?.downloadStatus == DownloadStatus.downloaded ? 1 : 0));
        if (downloadedImageCount == gallery.pageCount) {
          gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.downloaded.index);
        }
      }

      if (!await _restoreInfoInDatabase(gallery, images)) {
        Log.error('Restore download failed. Gallery: ${gallery.title}');
        _clearGalleryDownloadInfoInDatabase(gallery.gid);
        continue;
      }

      _initGalleryInfoInMemory(gallery, images: images);

      restoredCount++;
    }

    return restoredCount;
  }

  Future<void> updateImagePathAfterDownloadPathChanged() async {
    await appDb.transaction(() async {
      for (GalleryDownloadedData gallery in gallerys) {
        List<GalleryImage?> images = galleryDownloadInfos[gallery.gid]!.images;

        for (int serialNo = 0; serialNo < images.length; serialNo++) {
          if (images[serialNo] == null) {
            continue;
          }

          String newPath = _computeImageDownloadRelativePath(gallery.title, gallery.gid, images[serialNo]!.url, serialNo);

          if (await appDb.updateImagePath(newPath, gallery.gid, images[serialNo]!.url) <= 0) {
            Log.error('Update image path after download path changed failed');
          }
          images[serialNo]!.path = newPath;

          update(['$downloadImageId::${gallery.gid}', '$downloadImageUrlId::${gallery.gid}::$serialNo']);
        }
      }
    });
  }

  /// start executor
  void _startExecutor() {
    Log.info('Start download executor');

    executor = EHExecutor(
      concurrency: DownloadSetting.downloadTaskConcurrency.value,
      rate: Rate(DownloadSetting.maximum.value, DownloadSetting.period.value),
    );

    /// Resume gallery whose status is [downloading], order by insertTime
    for (GalleryDownloadedData g in gallerys.reversed) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        // gid2SpeedComputer[g.gid]!.start();
        downloadGallery(g, resume: true);
      }
    }
  }

  /// shutdown executor
  Future<void> _shutdownExecutor() async {
    Log.info('Shutdown download executor');

    await pauseAllDownloadGallery();
    executor.close();
  }

  void _submitTask({
    required int gid,
    required int priority,
    required AsyncTask<void> task,
  }) {
    galleryDownloadInfos[gid]?.tasks.add(task);

    executor.scheduleTask(priority, task).then((_) => galleryDownloadInfos[gid]?.tasks.remove(task)).catchError((e) {
      galleryDownloadInfos[gid]?.tasks.remove(task);
      if (e is! CancelException) {
        Log.error('Executor exception!', e);
        Log.upload(e);
      }
    });
  }

  Future<void> _instantiateFromDB() async {
    /// Get download info from database, order by insertTime DESC, serialNo
    List<SelectGallerysWithImagesResult> records = await appDb.selectGallerysWithImages().get();

    /// Instantiate from db
    for (SelectGallerysWithImagesResult record in records) {
      GalleryDownloadedData gallery = _record2Gallery(record);

      /// Instantiate [Gallery]
      if (gallerys.firstWhereOrNull((g) => g.gid == gallery.gid) == null) {
        _initGalleryInfoInMemory(gallery);
      }

      /// Current image has not been parsed, no need to instantiate GalleryImage
      if (record.url == null) {
        continue;
      }

      /// Instantiate [GalleryImage]
      GalleryImage image = GalleryImage(
        url: record.url!,
        height: record.height!,
        width: record.width!,
        path: record.path!,
        imageHash: record.imageHash!,
        downloadStatus: DownloadStatus.values[record.imageDownloadStatusIndex!],
      );

      galleryDownloadInfos[gallery.gid]!.images[record.serialNo!] = image;
      if (image.downloadStatus == DownloadStatus.downloaded) {
        galleryDownloadInfos[gallery.gid]!.downloadProgress.curCount++;
        galleryDownloadInfos[gallery.gid]!.downloadProgress.hasDownloaded[record.serialNo!] = true;
      }
    }
  }

  /// SelectGallerysWithImagesResult -> GalleryDownloadedData
  GalleryDownloadedData _record2Gallery(SelectGallerysWithImagesResult record) {
    return GalleryDownloadedData(
      gid: record.gid,
      token: record.token,
      title: record.title,
      category: record.category,
      pageCount: record.pageCount,
      galleryUrl: record.galleryUrl,
      oldVersionGalleryUrl: record.oldVersionGalleryUrl,
      uploader: record.uploader,
      publishTime: record.publishTime,
      downloadStatusIndex: record.galleryDownloadStatusIndex,
      insertTime: record.insertTime,
      downloadOriginalImage: record.downloadOriginalImage,
    );
  }

  int _computeDownloadPriority(String? galleryInsertTime) {
    DateTime time = galleryInsertTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parse(galleryInsertTime) : DateTime.now();

    /// other task's priority is less than 2000(maximum of images in a gallery), so we assign [_downloadGalleryPriorityBase] as 10000
    return DownloadSetting.downloadInOrder.isTrue
        ? _downloadGalleryPriorityBase + int.parse(DateFormat('MddHHmmss').format(time))
        : _defaultDownloadGalleryPriority;
  }

  String _computeGalleryTitle(String rawTitle) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();

    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trim();
    }

    return title;
  }

  String _computeGalleryDownloadPath(String rawTitle, int gid) {
    String title = _computeGalleryTitle(rawTitle);
    return path.join(DownloadSetting.downloadPath.value, '$gid - $title');
  }

  String _computeImageDownloadAbsolutePath(String title, int gid, String imageUrl, int serialNo) {
    /// original image's url doesn't has an ext
    String? ext = imageUrl.contains('fullimg.php') ? 'jpg' : imageUrl.split('.').last;

    return path.join(
      _computeGalleryDownloadPath(title, gid),
      '$serialNo.$ext',
    );
  }

  String _computeImageDownloadRelativePath(String title, int gid, String imageUrl, int serialNo) {
    return path.relative(
      _computeImageDownloadAbsolutePath(title, gid, imageUrl, serialNo),
      from: PathSetting.getVisibleDir().path,
    );
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) {
    return galleryDownloadInfos[gallery.gid] == null || galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus == DownloadStatus.paused;
  }

  // Task

  AsyncTask<void> _downloadGalleryTask(GalleryDownloadedData gallery) {
    return () {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      for (int serialNo = 0; serialNo < gallery.pageCount; serialNo++) {
        _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _processImageTask(gallery, serialNo),
        );
      }
    };
  }

  AsyncTask<void> _processImageTask(GalleryDownloadedData gallery, int serialNo) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

      /// has downloaded this image => nothing to do
      if (galleryDownloadInfo.images[serialNo]?.downloadStatus == DownloadStatus.downloaded) {
        return;
      }

      /// url has been parsed => download directly
      if (galleryDownloadInfo.images[serialNo]?.url != null) {
        return _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _downloadImageTask(gallery, serialNo),
        );
      }

      /// has parsed href => parse url
      if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
        return _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _parseImageUrlTask(gallery, serialNo),
        );
      }

      /// has not parsed href => parse href
      _submitTask(
        gid: gallery.gid,
        priority: serialNo,
        task: _parseImageHrefTask(gallery, serialNo),
      );
    };
  }

  AsyncTask<void> _parseImageHrefTask(GalleryDownloadedData gallery, int serialNo) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

      List<GalleryThumbnail> thumbnails;
      try {
        thumbnails = await retry(
          () => EHRequest.requestDetailPage(
            galleryUrl: gallery.galleryUrl,
            thumbnailsPageIndex: serialNo ~/ galleryDownloadInfo.thumbnailsCountPerPage,
            cancelToken: galleryDownloadInfo.cancelToken,
            parser: EHSpiderParser.detailPage2Thumbnails,
          ),
          retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
          onRetry: (e) => Log.download('Parse image hrefs failed, retry. Reason: ${(e as DioError).message}'),
          maxAttempts: _retryTimes,
        );
      } on DioError catch (e) {
        if (e.type == DioErrorType.cancel) {
          return;
        }

        if (e.error is EHException) {
          Log.download('Download error, reason: ${e.error.msg}');
          snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
          pauseAllDownloadGallery();
          return;
        }

        return _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _parseImageHrefTask(gallery, serialNo),
        );
      }

      /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
      /// For example, default setting is 40, but some gallerys' thumbnails has only high quality thumbnails, which results in 20.
      galleryDownloadInfo.thumbnailsCountPerPage = (thumbnails.length / 20).ceil() * 20;
      int from = serialNo ~/ galleryDownloadInfo.thumbnailsCountPerPage * galleryDownloadInfo.thumbnailsCountPerPage;

      CheckService.build(
        () => from + thumbnails.length <= galleryDownloadInfo.imageHrefs.length,
        errorMsg: "Out of index of imageHrefs!",
      ).withUploadParam({
        'pageCount': gallery.pageCount,
        'imageHrefsLength': galleryDownloadInfo.imageHrefs.length,
        'from': from,
        'thumbnailsLength': thumbnails.length,
      }).check(throwExceptionWhenFailed: false);

      for (int i = 0; i < thumbnails.length && from + i < galleryDownloadInfo.imageHrefs.length; i++) {
        galleryDownloadInfo.imageHrefs[from + i] = thumbnails[i];
      }

      /// if gallery's [thumbnailsCountPerPage] is not equal to default setting, we probably can't get target thumbnails this turn
      /// because the [thumbnailsPageIndex] we computed before is wrong, so we need to parse again
      if (galleryDownloadInfo.imageHrefs[serialNo] == null) {
        return _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _parseImageHrefTask(gallery, serialNo),
        );
      }

      /// Next step: parse image url
      _submitTask(
        gid: gallery.gid,
        priority: serialNo,
        task: _parseImageUrlTask(gallery, serialNo),
      );
    };
  }

  AsyncTask<void> _parseImageUrlTask(GalleryDownloadedData gallery, int serialNo, {bool reParse = false}) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

      GalleryImage image;
      try {
        image = await retry(
          () => EHRequest.requestImagePage(
            galleryDownloadInfo.imageHrefs[serialNo]!.href,
            cancelToken: galleryDownloadInfo.cancelToken,
            useCacheIfAvailable: !reParse,
            parser: gallery.downloadOriginalImage && EHCookieManager.userCookies.isNotEmpty
                ? EHSpiderParser.imagePage2OriginalGalleryImage
                : EHSpiderParser.imagePage2GalleryImage,
          ),
          retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
          onRetry: (e) => Log.download('Parse image url failed, retry. Reason: ${(e as DioError).message}'),
          maxAttempts: _retryTimes,
        );
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

        return _submitTask(
          gid: gallery.gid,
          priority: serialNo,
          task: _parseImageUrlTask(gallery, serialNo, reParse: true),
        );
      }

      image.path = _computeImageDownloadRelativePath(gallery.title, gallery.gid, image.url, serialNo);
      image.downloadStatus = DownloadStatus.downloading;
      galleryDownloadInfo.images[serialNo] = image;

      await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);

      /// Next step: download image
      return _submitTask(
        gid: gallery.gid,
        priority: serialNo,
        task: _downloadImageTask(gallery, serialNo),
      );
    };
  }

  AsyncTask<void> _downloadImageTask(GalleryDownloadedData gallery, int serialNo) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
      GalleryImage image = galleryDownloadInfo.images[serialNo]!;

      _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloading);

      /// If this is a update from old gallery, try to copy from existing old image first
      if (gallery.oldVersionGalleryUrl != null) {
        await _tryCopyImageInfo(gallery.oldVersionGalleryUrl!, gallery, serialNo);

        if (image.downloadStatus == DownloadStatus.downloaded) {
          return;
        }
      }

      Response response;
      try {
        response = await retry(
          () => EHRequest.download(
            url: image.url,
            path: _computeImageDownloadAbsolutePath(gallery.title, gallery.gid, image.url, serialNo),
            cancelToken: galleryDownloadInfo.cancelToken,
            onReceiveProgress: (int count, int total) => galleryDownloadInfo.speedComputer.updateProgress(count, total, serialNo),
          ),
          maxAttempts: _retryTimes,

          /// 403 is due to token error(maybe... I forgot the reason)
          retryIf: (e) =>
              e is DioError && e.type != DioErrorType.cancel && e.error is! EHException && (e.response == null || e.response!.statusCode != 403),
          onRetry: (e) {
            Log.download('Download ${gallery.title} image: $serialNo failed, retry. Reason: ${(e as DioError).message}. Url:${image.url}');
            galleryDownloadInfo.speedComputer.resetProgress(serialNo);
          },
        );
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

        Log.download('Download ${gallery.title} image: $serialNo failed, try re-parse. Reason: ${e.message}. Url:${image.url}');
        return _reParseImageUrlAndDownload(gallery, serialNo);
      }

      if (_isInvalidToken(gallery, response)) {
        Log.warning('Invalid original image token, url: ${image.url}');
        return _reParseImageUrlAndDownload(gallery, serialNo);
      }

      Log.download('Download ${gallery.title} image: $serialNo success');

      await _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloaded);

      await _updateProgressAfterImageDownloaded(gallery, serialNo);
    };
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

    await appDb.deleteImage(gallery.gid, galleryDownloadInfo.images[serialNo]!.url);

    /// has parsed href => parse url
    if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
      return _submitTask(
        gid: gallery.gid,
        priority: serialNo,
        task: _parseImageUrlTask(gallery, serialNo, reParse: true),
      );
    }

    /// has not parsed href => parse href
    return _submitTask(
      gid: gallery.gid,
      priority: serialNo,
      task: _parseImageHrefTask(gallery, serialNo),
    );
  }

  /// If two images' [imageHash] is equal, they are the same image.
  Future<void> _tryCopyImageInfo(String oldVersionGalleryUrl, GalleryDownloadedData newGallery, int newImageSerialNo) async {
    GalleryDownloadedData? oldGallery = gallerys.firstWhereOrNull((e) => e.galleryUrl == oldVersionGalleryUrl);
    if (oldGallery == null) {
      return;
    }

    String newImageHash = galleryDownloadInfos[newGallery.gid]!.images[newImageSerialNo]!.imageHash!;

    GalleryImage? oldImage = galleryDownloadInfos[oldGallery.gid]?.images.firstWhereOrNull((e) => e?.imageHash == newImageHash);
    if (oldImage == null) {
      return;
    }

    return await _copyImageInfo(oldImage, newGallery, newImageSerialNo);
  }

  Future<void> _copyImageInfo(GalleryImage oldImage, GalleryDownloadedData newGallery, int newImageSerialNo) async {
    Log.download('Copy old image, new serialNo: $newImageSerialNo');

    GalleryImage newImage = galleryDownloadInfos[newGallery.gid]!.images[newImageSerialNo]!;

    io.File oldFile = io.File(path.join(PathSetting.getVisibleDir().path, oldImage.path!));
    oldFile.copySync(path.join(PathSetting.getVisibleDir().path, newImage.path!));

    await _updateImageStatus(newGallery, newImage, newImageSerialNo, DownloadStatus.downloaded);

    _updateProgressAfterImageDownloaded(newGallery, newImageSerialNo);
  }

  Future<void> _updateProgressAfterImageDownloaded(GalleryDownloadedData gallery, int serialNo) async {
    GalleryDownloadProgress downloadProgress = galleryDownloadInfos[gallery.gid]!.downloadProgress;
    downloadProgress.curCount++;
    downloadProgress.hasDownloaded[serialNo] = true;

    if (downloadProgress.curCount == downloadProgress.totalCount) {
      downloadProgress.downloadStatus = DownloadStatus.downloaded;
      await _updateGalleryDownloadStatus(gallery, DownloadStatus.downloaded);
      galleryDownloadInfos[gallery.gid]!.speedComputer.dispose();
    }

    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  /// We need a token in url to get the original image download url, expired token will leads to a failed request,
  bool _isInvalidToken(GalleryDownloadedData gallery, Response response) {
    if (!gallery.downloadOriginalImage) {
      return false;
    }
    return !(response.isRedirect ?? true) && (response.headers[Headers.contentTypeHeader]?.contains("text/html; charset=UTF-8") ?? false);
  }

  // ALL

  Future<bool> _initGalleryInfo(GalleryDownloadedData gallery) async {
    if (!await _saveGalleryInfoInDB(gallery)) {
      return false;
    }

    _initGalleryInfoInMemory(gallery);

    _saveGalleryInfoInDisk(gallery);

    return true;
  }

  Future<void> _updateGalleryDownloadStatus(GalleryDownloadedData gallery, DownloadStatus downloadStatus) async {
    await _updateGalleryStatusInDatabase(gallery.gid, downloadStatus);

    gallerys[gallerys.indexWhere((e) => e.gid == gallery.gid)] = gallery.copyWith(downloadStatusIndex: downloadStatus.index);
    galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus = downloadStatus;

    _saveGalleryInfoInDisk(gallery);
  }

  Future<bool> _updateImageStatus(GalleryDownloadedData gallery, GalleryImage image, int serialNo, DownloadStatus downloadStatus) async {
    if (!await _updateImageStatusInDatabase(gallery.gid, image.url, downloadStatus)) {
      return false;
    }

    image.downloadStatus = downloadStatus;

    update(['$downloadImageId::${gallery.gid}', '$downloadImageUrlId::${gallery.gid}::$serialNo']);

    _saveGalleryInfoInDisk(gallery);

    return true;
  }

  // MEMORY

  void _initGalleryInfoInMemory(GalleryDownloadedData gallery, {List<GalleryImage?>? images}) {
    gallerys.add(gallery);
    gallerys.sort((a, b) => (b.insertTime ?? "").compareTo(a.insertTime ?? ""));

    galleryDownloadInfos[gallery.gid] = GalleryDownloadInfo(
      thumbnailsCountPerPage: SiteSetting.thumbnailsCountPerPage.value,
      tasks: [],
      cancelToken: CancelToken(),
      downloadProgress: GalleryDownloadProgress(
        curCount: images?.fold<int>(0, (total, image) => total + (image?.downloadStatus == DownloadStatus.downloaded ? 1 : 0)) ?? 0,
        totalCount: gallery.pageCount,
        downloadStatus: DownloadStatus.values[gallery.downloadStatusIndex],
        hasDownloaded:
            images?.map((image) => image?.downloadStatus == DownloadStatus.downloaded).toList() ?? List.generate(gallery.pageCount, (_) => false),
      ),
      imageHrefs: List.generate(gallery.pageCount, (_) => null),
      images: images ?? List.generate(gallery.pageCount, (_) => null),
      speedComputer: GalleryDownloadSpeedComputer(
        gallery.pageCount,
        () => update(['$galleryDownloadSpeedComputerId::${gallery.gid}']),
      ),
    );

    update([initGalleryId, galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryInfoInMemory(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadInfos.remove(gallery.gid);
    galleryDownloadInfo?.speedComputer.dispose();

    update([removeGalleryId, galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  // DB

  Future<bool> _saveGalleryInfoInDB(GalleryDownloadedData gallery) async {
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
          gallery.insertTime ?? DateTime.now().toString(),
          gallery.downloadOriginalImage,
        ) >
        0;
  }

  Future<bool> _saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) async {
    return await appDb.insertImage(
          image.url,
          serialNo,
          gid,
          image.height,
          image.width,
          image.path!,
          image.imageHash!,
          image.downloadStatus.index,
        ) >
        0;
  }

  Future<bool> _updateGalleryStatusInDatabase(int gid, DownloadStatus downloadStatus) async {
    return await appDb.updateGallery(downloadStatus.index, gid) > 0;
  }

  Future<bool> _updateImageStatusInDatabase(int gid, String url, DownloadStatus downloadStatus) async {
    return await appDb.updateImageStatus(downloadStatus.index, gid, url) > 0;
  }

  Future<void> _clearGalleryDownloadInfoInDatabase(int gid) {
    return appDb.transaction(() async {
      await appDb.deleteImagesWithGid(gid);
      await appDb.deleteGallery(gid);
    });
  }

  Future<bool> _restoreInfoInDatabase(GalleryDownloadedData gallery, List<GalleryImage?> images) async {
    if (gallery.downloadStatusIndex == DownloadStatus.downloading.index) {
      gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
    }

    if (!await _saveGalleryInfoInDB(gallery)) {
      return false;
    }

    return await appDb.transaction(() async {
      int serialNo = 0;

      Iterator iterator = images.iterator;
      while (iterator.moveNext()) {
        GalleryImage? image = iterator.current;

        if (image == null) {
          serialNo++;
          continue;
        }

        if (!await _saveNewImageInfoInDatabase(image, serialNo++, gallery.gid)) {
          return false;
        }
      }

      return true;
    }).catchError((e) {
      Log.error('Restore images into database error}', e);
      Log.upload(e);
      return false;
    });
  }

  // Disk

  void _saveGalleryInfoInDisk(GalleryDownloadedData gallery) {
    Map<String, Object> metadata = {
      'gallery': gallery.copyWith(downloadStatusIndex: galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus.index).toJson(),
      'images': jsonEncode(galleryDownloadInfos[gallery.gid]!.images),
    };

    io.File file = io.File(path.join(_computeGalleryDownloadPath(gallery.title, gallery.gid), _metadata));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(jsonEncode(metadata));
  }

  void _clearDownloadedImageInDisk(GalleryDownloadedData gallery) {
    io.Directory directory = io.Directory(_computeGalleryDownloadPath(gallery.title, gallery.gid));
    if (!directory.existsSync()) {
      return;
    }
    directory.deleteSync(recursive: true);
  }

  void _ensureDownloadDirExists() {
    io.Directory(DownloadSetting.downloadPath.value).createSync(recursive: true);
  }
}

enum DownloadStatus {
  none,
  switching,
  paused,
  downloading,
  downloaded,
  downloadFailed,
}

class GalleryDownloadInfo {
  /// There are 2 kinds of thumbnails list in e-hentai: normal(40) and large(20).
  int thumbnailsCountPerPage;

  /// Tasks in Executor
  List<AsyncTask> tasks;

  /// Token for cancel all tasks related to a gallery
  CancelToken cancelToken;

  GalleryDownloadProgress downloadProgress;

  /// Thumbnail related to a image, whose property [href] is the page url which contains the image
  List<GalleryThumbnail?> imageHrefs;

  List<GalleryImage?> images;

  GalleryDownloadSpeedComputer speedComputer;

  GalleryDownloadInfo({
    required this.thumbnailsCountPerPage,
    required this.tasks,
    required this.cancelToken,
    required this.downloadProgress,
    required this.imageHrefs,
    required this.images,
    required this.speedComputer,
  });
}

class GalleryDownloadProgress {
  /// downloaded images count
  int curCount;

  /// total images count
  int totalCount;

  DownloadStatus downloadStatus;

  List<bool> hasDownloaded;

  GalleryDownloadProgress({
    required this.curCount,
    required this.totalCount,
    required this.downloadStatus,
    required this.hasDownloaded,
  });

  Map<String, dynamic> toJson() {
    return {
      "curCount": curCount,
      "totalCount": totalCount,
      "downloadStatus": downloadStatus.index,
      "hasDownloaded": jsonEncode(hasDownloaded),
    };
  }

  factory GalleryDownloadProgress.fromJson(Map<String, dynamic> json) {
    return GalleryDownloadProgress(
      curCount: json["curCount"],
      totalCount: json["totalCount"],
      downloadStatus: DownloadStatus.values[json["downloadStatus"]],
      hasDownloaded: (jsonDecode(json["hasDownloaded"]) as List).cast<bool>(),
    );
  }
}

/// Compute gallery download speed during last period every second
class GalleryDownloadSpeedComputer extends SpeedComputer {
  List<int> imageDownloadedBytes;
  List<int> imageTotalBytes;

  GalleryDownloadSpeedComputer(int pageCount, VoidCallback updateCallback)
      : imageDownloadedBytes = List.generate(pageCount, (_) => 0),
        imageTotalBytes = List.generate(pageCount, (_) => 1),
        super(updateCallback: updateCallback);

  void updateProgress(int current, int total, int serialNo) {
    imageTotalBytes[serialNo] = total;

    downloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = current;
    downloadedBytes += imageDownloadedBytes[serialNo];
  }

  /// one image download failed
  void resetProgress(int serialNo) {
    downloadedBytes -= imageDownloadedBytes[serialNo];
    imageDownloadedBytes[serialNo] = 0;
  }
}
