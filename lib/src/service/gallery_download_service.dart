import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:executor/executor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/database/dao/gallery_group_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/exception/eh_image_exception.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/jh_response/fetch_image_hashes_vo.dart';
import 'package:jhentai/src/model/jh_response/jh_response.dart';
import 'package:jhentai/src/network/jh_request.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/jh_response_parser.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

import '../consts/locale_consts.dart';
import '../database/dao/gallery_image_dao.dart';
import '../exception/cancel_exception.dart';
import '../exception/eh_site_exception.dart';
import 'download_path_resolver.dart';
import 'gallery_image_cache.dart';
import 'gallery_metadata_store.dart';
import 'gallery_upgrade_migrator.dart';
import '../model/comic_info.dart';
import '../model/detail_page_info.dart';
import '../model/gallery_detail.dart';
import '../model/gallery_image.dart';
import '../network/eh_request.dart';
import '../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../utils/eh_executor.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/snack_util.dart';
import 'jh_service.dart';
import 'path_service.dart';

/// Responsible for local images meta-data and download all images of a gallery
GalleryDownloadService galleryDownloadService = GalleryDownloadService();

class GalleryDownloadService extends GetxController with GridBasePageServiceMixin, JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  final String downloadImageId = 'downloadImageId';
  final String downloadImageUrlId = 'downloadImageUrlId';
  final String galleryDownloadProgressId = 'galleryDownloadProgressId';
  final String galleryDownloadSpeedComputerId = 'galleryDownloadSpeedComputerId';
  final String galleryDownloadSuccessId = 'galleryDownloadSuccessId';

  late EHExecutor executor;

  List<String> allGroups = [];
  Map<int, GalleryDownloadInfo> galleryDownloadInfos = {};

  /// Sorted view synthesized from [galleryDownloadInfos]. Single source of
  /// truth — the map holds the data; this getter returns a sorted snapshot.
  List<GalleryDownloadedData> get gallerys {
    final list = galleryDownloadInfos.values.map((i) => i.toGalleryDownloadedData()).toList();
    _sortGalleryData(list);
    return list;
  }

  List<GalleryDownloadedData> gallerysWithGroup(String group) =>
      gallerys.where((g) => galleryDownloadInfos[g.gid]!.group == group).toList();

  static const int _maxRetryTimes = 3;
  static const int _maxRetryTimes4FetchImageHashes = 1;
  static const int defaultDownloadGalleryPriority = 4;

  /// Backward-compat alias — external callers read this const to locate the
  /// metadata file. The canonical home is now [GalleryMetadataStore].
  static const String metadataFileName = GalleryMetadataStore.metadataFileName;
  static const int _priorityBase = 100000000;

  final Completer<bool> _completer = Completer();

  Future<bool> get completed => _completer.future;

  Worker? _downloadSettingListener;

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);

    await _instantiateFromDB();

    log.debug('Gallery download task count: ${gallerys.length}');

    _startExecutor();

    _completer.complete(true);

    if (downloadSetting.restoreTasksAutomatically.isTrue) {
      await restoreTasks();
    }

    _downloadSettingListener = everAll(
      [downloadSetting.downloadTaskConcurrency, downloadSetting.maximum, downloadSetting.period],
      (_) {
        updateExecutor();
      },
    );
  }

  @override
  Future<void> doAfterBeanReady() async {}

  @override
  void onClose() {
    super.onClose();

    _downloadSettingListener?.dispose();
  }

  bool containGallery(int gid) => galleryDownloadInfos.containsKey(gid);

  Future<void> downloadGallery(GalleryDownloadedData gallery, {bool resume = false}) async {
    if (!resume && containGallery(gallery.gid)) {
      return;
    }

    _ensureDownloadDirExists();

    /// If it's a new download task, record info.
    if (!resume) {
      GalleryDownloadedData? galleryWithSanitizedTitle = await _initGalleryInfo(gallery);
      if (galleryWithSanitizedTitle == null) {
        return;
      }
      gallery = galleryWithSanitizedTitle;

      _generateComicInfoInDisk(gallery);
    }

    galleryDownloadInfos[gallery.gid]!.speedComputer.start();

    /// Pre-load full imagesCache so synchronous reads during download (e.g.
    /// `_downloadImageTask` reading `image.url`) work without per-call awaits.
    await galleryDownloadInfos[gallery.gid]!.ensureImagesCacheLoaded();

    log.info('Begin to download gallery: ${gallery.title}, original: ${gallery.downloadOriginalImage}');

    _submitTask(
      gid: gallery.gid,
      priority: _computeGalleryTaskPriority(gallery),
      task: _downloadGalleryTask(gallery),
    );
  }

  Future<void> pauseAllDownloadGallery() async {
    await Future.wait(gallerys.map(pauseDownloadGallery).toList());
  }

  GalleryDownloadedData? _findGalleryByGid(int gid) => gallerys.firstWhereOrNull((gallery) => gallery.gid == gid);

  Future<void> pauseDownloadGalleryByGid(int gid) async {
    GalleryDownloadedData? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return pauseDownloadGallery(gallery);
    }
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
    GalleryDownloadProgress downloadProgress = galleryDownloadInfo.downloadProgress;

    if (downloadProgress.downloadStatus != DownloadStatus.downloading) {
      return;
    }

    if (!await _updateGalleryInDatabase(
      GalleryDownloadedCompanion(gid: Value(gallery.gid), downloadStatusIndex: Value(DownloadStatus.paused.index)),
    )) {
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

    for (GalleryImageIndex? idx in galleryDownloadInfo.imageIndices) {
      /// no need to update db
      if (idx?.downloadStatus == DownloadStatus.downloading) {
        idx?.downloadStatus = DownloadStatus.paused;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    await _flushMetadataSave(gallery);

    log.info('Pause download gallery: ${gallery.title}');
  }

  Future<void> resumeAllDownloadGallery() async {
    await Future.wait(gallerys.map(resumeDownloadGallery).toList());
  }

  Future<void> resumeDownloadGalleryByGid(int gid) async {
    GalleryDownloadedData? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return resumeDownloadGallery(gallery);
    }
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
    GalleryDownloadProgress downloadProgress = galleryDownloadInfo.downloadProgress;

    if (downloadProgress.downloadStatus != DownloadStatus.paused) {
      return;
    }

    if (!await _updateGalleryInDatabase(
      GalleryDownloadedCompanion(gid: Value(gallery.gid), downloadStatusIndex: Value(DownloadStatus.downloading.index)),
    )) {
      return;
    }

    downloadProgress.downloadStatus = DownloadStatus.downloading;
    update(['$galleryDownloadProgressId::${gallery.gid}']);

    /// can't reuse
    galleryDownloadInfo.cancelToken = CancelToken();
    galleryDownloadInfo.speedComputer.start();

    for (GalleryImageIndex? idx in galleryDownloadInfo.imageIndices) {
      /// no need to update db
      if (idx?.downloadStatus == DownloadStatus.paused) {
        idx?.downloadStatus = DownloadStatus.downloading;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    log.info('Resume download gallery: ${gallery.title}');

    _saveGalleryMetadataInDisk(gallery);

    downloadGallery(gallery, resume: true);
  }

  Future<void> deleteGalleryByGid(int gid) async {
    GalleryDownloadedData? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return deleteGallery(gallery);
    }
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery, {bool deleteImages = true}) async {
    await pauseDownloadGallery(gallery);

    log.info('Delete download gallery: ${gallery.title}, deleteImages:$deleteImages');

    await superResolutionService.deleteSuperResolve(gallery.gid, SuperResolutionType.gallery);

    await _clearGalleryDownloadInfoInDatabase(gallery.gid);
    if (deleteImages) {
      _clearDownloadedImageInDisk(gallery);
    }
    _clearGalleryInfoInMemory(gallery);
  }

  /// Update local downloaded gallery if there's a new version.
  Future<void> updateGallery(GalleryDownloadedData oldGallery, GalleryUrl newVersionGalleryUrl) async {
    log.info('update gallery: ${oldGallery.title}');

    GalleryDetail newGalleryDetail;
    try {
      ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await retry(
        () => ehRequest.requestDetailPage(galleryUrl: newVersionGalleryUrl.url, parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: _maxRetryTimes,
      );
      newGalleryDetail = detailPageInfo.galleryDetails;
    } on DioException catch (e) {
      log.info('${'updateGalleryError'.tr}, reason: ${e.errorMsg}');
      snack('updateGalleryError'.tr, e.errorMsg ?? '', isShort: true);
      return;
    } on EHSiteException catch (e) {
      log.info('${'updateGalleryError'.tr}, reason: ${e.message}');
      snack('updateGalleryError'.tr, e.message, isShort: true);
      pauseAllDownloadGallery();
      return;
    }

    GalleryDownloadedData newGallery = GalleryDownloadedData(
      gid: newGalleryDetail.galleryUrl.gid,
      token: newGalleryDetail.galleryUrl.token,
      title: newGalleryDetail.japaneseTitle ?? newGalleryDetail.rawTitle,
      category: newGalleryDetail.category,
      pageCount: newGalleryDetail.pageCount,
      oldVersionGalleryUrl: oldGallery.galleryUrl,
      galleryUrl: newGalleryDetail.galleryUrl.url,
      uploader: newGalleryDetail.uploader,
      publishTime: newGalleryDetail.publishTime,
      downloadStatusIndex: DownloadStatus.downloading.index,
      insertTime: DateTime.now().toString(),
      downloadOriginalImage: oldGallery.downloadOriginalImage,
      priority: GalleryDownloadService.defaultDownloadGalleryPriority,
      sortOrder: 0,
      groupName: galleryDownloadInfos[oldGallery.gid]!.group,
      tags: tagMap2TagString(newGalleryDetail.tags),
      tagRefreshTime: DateTime.now().toString(),
    );

    downloadGallery(newGallery);
  }

  Future<void> importGallery(GalleryDownloadedData gallery, List<GalleryImage> images) async {
    if (containGallery(gallery.gid)) {
      return;
    }

    log.info('Import gallery: ${gallery.title}');

    _ensureDownloadDirExists();

    io.Directory galleryDir = io.Directory(computeGalleryDownloadAbsolutePath(gallery));
    if (!galleryDir.existsSync()) {
      galleryDir.createSync(recursive: true);
    }

    List<Future> futures = [];
    List<GalleryImage> copiedImages = [];
    for (int i = 0; i < images.length; i++) {
      GalleryImage image = images[i];
      String oldPath = computeImageDownloadAbsolutePathFromRelativePath(image.path!);
      String newPath = _computeImageDownloadAbsolutePath(gallery, image.url, i);
      futures.add(io.File(oldPath).copy(newPath));

      copiedImages.add(image.copyWith(path: _computeImageDownloadRelativePath(gallery, image.url, i)));
    }

    await Future.wait(futures);

    if (!await _restoreInfoInDatabase(gallery, copiedImages)) {
      log.error('Import gallery failed: ${gallery.title}');
      _clearGalleryDownloadInfoInDatabase(gallery.gid);
      return;
    }

    _initGalleryInfoInMemory(
      gallery,
      imageIndices: copiedImages
          .asMap()
          .map((i, img) => MapEntry(
              i,
              GalleryImageIndex(
                serialNo: i,
                url: img.url,
                path: img.path,
                downloadStatus: img.downloadStatus,
                imageHash: img.imageHash,
              )))
          .values
          .toList(),
    );

    _saveGalleryMetadataInDisk(gallery);
  }

  Future<void> reDownloadGalleryByGid(int gid) async {
    GalleryDownloadedData? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return reDownloadGallery(gallery);
    }
  }

  Future<void> reDownloadGallery(GalleryDownloadedData gallery) async {
    log.info('Re-download gallery: ${gallery.gid}');

    await deleteGallery(gallery);

    downloadGallery(gallery);
  }

  Future<void> reDownloadImage(int gid, int serialNo) async {
    GalleryDownloadedData? gallery = gallerys.singleWhereOrNull((g) => g.gid == gid);
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadInfos[gid];

    if (gallery == null || galleryDownloadInfo == null || galleryDownloadInfo.indexAt(serialNo) == null) {
      return;
    }

    await galleryDownloadInfo.ensureImagesCacheLoaded();
    GalleryImage? image = galleryDownloadInfo.imageAtSync(serialNo);

    if (image == null) {
      return;
    }

    log.info('Re-download image, gid: $gid, index: $serialNo');

    if (galleryDownloadInfo.downloadProgress.hasDownloaded[serialNo] == true) {
      galleryDownloadInfo.downloadProgress.curCount--;
    }
    galleryDownloadInfo.downloadProgress.hasDownloaded[serialNo] = false;
    galleryDownloadInfo.speedComputer.resetProgress(serialNo);
    galleryDownloadInfo.speedComputer.start();
    await _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloading);
    await _updateGalleryDownloadStatus(gallery, DownloadStatus.downloading);
    _deleteImageInDisk(image);

    update(['$galleryDownloadSuccessId::${gallery.gid}', '$galleryDownloadProgressId::${gallery.gid}']);

    _reParseImageUrlAndDownload(gallery, serialNo);
  }

  Future<void> assignPriority(GalleryDownloadedData gallery, int priority) async {
    if (priority == galleryDownloadInfos[gallery.gid]?.priority) {
      return;
    }

    log.info('Assign priority, gid: ${gallery.gid}, priority: $priority');

    if (!await _updateGalleryInDatabase(
      GalleryDownloadedCompanion(gid: Value(gallery.gid), priority: Value(priority)),
    )) {
      return;
    }

    galleryDownloadInfos[gallery.gid]!.priority = priority;

    if (galleryDownloadInfos[gallery.gid]?.downloadProgress.downloadStatus == DownloadStatus.downloading) {
      await pauseDownloadGallery(gallery);
      await resumeDownloadGallery(gallery);
    }
  }

  Future<bool> updateGroupByGid(int gid, String group) async {
    GalleryDownloadedData? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return updateGroup(gallery, group);
    }
    return false;
  }

  Future<bool> updateGroup(GalleryDownloadedData gallery, String group) async {
    /// Atomically create the group (if new) and update the gallery's group column.
    /// Without a transaction, a failure in the gallery update would leave an orphan
    /// group row in [gallery_group] — and in-memory state would already be mutated.
    bool success = await appDb.transaction(() async {
      if (!allGroups.contains(group) && !await _addGroup(group)) {
        return false;
      }
      return _updateGalleryInDatabase(
        GalleryDownloadedCompanion(gid: Value(gallery.gid), groupName: Value(group)),
      );
    });

    if (!success) {
      return false;
    }

    galleryDownloadInfos[gallery.gid]?.group = group;
    _sortGallerys();
    _saveGalleryMetadataInDisk(gallery);

    return true;
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    List<GalleryDownloadedData> galleryDownloadedDatas = gallerys.where((g) => galleryDownloadInfos[g.gid]!.group == oldGroup).toList();

    await appDb.transaction(() async {
      if (!allGroups.contains(newGroup) && !await _addGroup(newGroup)) {
        return;
      }

      for (GalleryDownloadedData g in galleryDownloadedDatas) {
        galleryDownloadInfos[g.gid]!.group = newGroup;
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(g.gid), groupName: Value(newGroup)),
        );
        _saveGalleryMetadataInDisk(g);
      }

      await _deleteGroup(oldGroup);
    });

    _sortGallerys();
  }

  Future<void> deleteGroup(String group) {
    return _deleteGroup(group);
  }

  Future<void> updateGalleryOrder(List<GalleryDownloadedData> gallerys) async {
    await appDb.transaction(() async {
      for (GalleryDownloadedData gallery in gallerys) {
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(gallery.gid), sortOrder: Value(galleryDownloadInfos[gallery.gid]!.sortOrder)),
        );
      }
    });

    _sortGallerys();

    for (GalleryDownloadedData gallery in gallerys) {
      _saveGalleryMetadataInDisk(gallery);
    }
  }

  Future<void> updateGroupOrder(int beforeIndex, int afterIndex) async {
    if (afterIndex == allGroups.length - 1) {
      allGroups.add(allGroups.removeAt(beforeIndex));
    } else {
      allGroups.insert(afterIndex, allGroups.removeAt(beforeIndex));
    }

    log.info('Update group order: $allGroups');

    await appDb.transaction(() async {
      for (int i = 0; i < allGroups.length; i++) {
        await GalleryGroupDao.updateGalleryGroupOrder(allGroups[i], i);
      }
    });
  }

  bool isUpdatingDependent(int gid) {
    GalleryDownloadedData? gallery = gallerys.firstWhereOrNull((g) => g.gid == gid);
    if (gallery == null) {
      return false;
    }

    GalleryDownloadedData? oldGallery = gallerys.firstWhereOrNull((g) => g.oldVersionGalleryUrl == gallery.galleryUrl);
    if (oldGallery == null) {
      return false;
    }

    return galleryDownloadInfos[oldGallery.gid]!.downloadProgress.downloadStatus != DownloadStatus.downloaded;
  }

  /// Use metadata in each gallery folder to restore download status, then sync to database.
  /// This is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    await completed;

    io.Directory downloadDir = io.Directory(downloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    for (io.FileSystemEntity galleryDir in downloadDir.listSync()) {
      Map<String, dynamic>? metadata = _metadataStore.read(io.Directory(galleryDir.path));
      if (metadata == null) {
        continue;
      }

      GalleryDownloadedData gallery = GalleryDownloadedData.fromJson(metadata['gallery']);

      /// Back-fill sanitizedTitle for metadata files written before this field was introduced.
      if (gallery.sanitizedTitle == null) {
        final int reservedBytes = utf8.encode('${gallery.gid} - ').length;
        gallery = gallery.copyWith(sanitizedTitle: Value(_computeSanitizedGalleryTitle(gallery.title, reservedBytes)));
      }
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
        images[serialNo]!.path = _computeImageDownloadRelativePath(gallery, images[serialNo]!.url, serialNo);
        images[serialNo]!.imageHash ??= '';
      }

      /// For some reason, downloaded status is not updated correctly, check it again
      if (gallery.downloadStatusIndex != DownloadStatus.downloaded.index) {
        int downloadedImageCount = images.fold(0, (total, image) => total + (image?.downloadStatus == DownloadStatus.downloaded ? 1 : 0));
        if (downloadedImageCount == gallery.pageCount) {
          gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.downloaded.index);
        }
      }

      if (!await _restoreInfoInDatabase(gallery, images)) {
        log.error('Restore download failed. Gallery: ${gallery.title}');
        _clearGalleryDownloadInfoInDatabase(gallery.gid);
        continue;
      }

      /// Build imageIndices from the restored images (index fields only).
      List<GalleryImageIndex?> restoredIndices = List.generate(gallery.pageCount, (_) => null);
      for (int serialNo = 0; serialNo < images.length && serialNo < gallery.pageCount; serialNo++) {
        final img = images[serialNo];
        if (img != null) {
          restoredIndices[serialNo] = GalleryImageIndex(
            serialNo: serialNo,
            url: img.url,
            path: img.path,
            downloadStatus: img.downloadStatus,
            imageHash: img.imageHash,
          );
        }
      }

      _initGalleryInfoInMemory(gallery, imageIndices: restoredIndices, sort: false);

      restoredCount++;
    }

    if (restoredCount > 0) {
      _sortGallerys();
    }

    return restoredCount;
  }

  Future<void> updateImagePathAfterDownloadPathChanged() async {
    await appDb.transaction(() async {
      for (GalleryDownloadedData gallery in gallerys) {
        GalleryDownloadInfo info = galleryDownloadInfos[gallery.gid]!;
        await info.ensureImageIndicesLoaded();

        for (int serialNo = 0; serialNo < info.imageIndices.length; serialNo++) {
          GalleryImageIndex? idx = info.indexAt(serialNo);
          if (idx == null) {
            continue;
          }

          String newPath = _computeImageDownloadRelativePath(gallery, idx.url, serialNo);

          if (!await _updateImageInDatabase(
            ImageCompanion(gid: Value(gallery.gid), serialNo: Value(serialNo), path: Value(newPath)),
          )) {
            log.error('Update image path after download path changed failed');
          }
          info.updateImagePath(serialNo, newPath);

          update(['$downloadImageId::${gallery.gid}::$serialNo', '$downloadImageUrlId::${gallery.gid}::$serialNo']);
        }
      }
    });
  }

  /// Order matters: more specific patterns must come before generic ones.
  static final List<({String pattern, EHImageExceptionType type, String Function() message, EHImageExceptionAfterOperation operation})> _imageExceptionMatchers =
      [
        (pattern: 'Downloading original files of this gallery during peak hours requires GP, and you do not have enough.', type: EHImageExceptionType.peakHours, message: () => 'peakHoursHint'.tr, operation: EHImageExceptionAfterOperation.pause),
        (pattern: 'Downloading original files of this gallery requires GP, and you do not have enough.', type: EHImageExceptionType.peakHours, message: () => 'oldGalleryHint'.tr, operation: EHImageExceptionAfterOperation.pause),
        (pattern: 'You have reached the image limit, and do not have sufficient GP to buy a download quota.', type: EHImageExceptionType.peakHours, message: () => 'exceedLimitHint'.tr, operation: EHImageExceptionAfterOperation.pauseAll),
        (pattern: 'Invalid token', type: EHImageExceptionType.invalidToken, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
        (pattern: 'Invalid request', type: EHImageExceptionType.serverError, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
        (pattern: 'An error has occurred', type: EHImageExceptionType.serverError, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
      ];

  static EHImageException? imageData2Exception(String imageFileData) {
    if (imageFileData.isEmpty) {
      return EHImageException(
        type: EHImageExceptionType.blankImage,
        message: 'blankImageHint'.tr,
        operation: EHImageExceptionAfterOperation.reParse,
      );
    }

    for (final m in _imageExceptionMatchers) {
      if (imageFileData.contains(m.pattern)) {
        return EHImageException(type: m.type, message: m.message(), operation: m.operation);
      }
    }

    return EHImageException(
      type: EHImageExceptionType.serverError,
      message: imageFileData,
      operation: EHImageExceptionAfterOperation.pause,
    );
  }

  Future<void> _generateComicInfoInDisk(GalleryDownloadedData gallery) async {
    GalleryDetail galleryDetail;
    try {
      ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await retry(
        () => ehRequest.requestDetailPage(galleryUrl: gallery.galleryUrl, parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey),
        retryIf: (e) => e is DioException,
        maxAttempts: _maxRetryTimes,
      );
      galleryDetail = detailPageInfo.galleryDetails;
    } catch (e) {
      log.error('Get gallery detail failed, gallery: ${gallery.gid}', e);
      return;
    }

    if (_taskHasBeenRemoved(gallery)) {
      return;
    }

    EHGalleryComicInfo galleryComicInfo = EHGalleryComicInfo(
      rawTitle: galleryDetail.rawTitle,
      japaneseTitle: galleryDetail.japaneseTitle,
      category: galleryDetail.category,
      pageCount: galleryDetail.pageCount,
      galleryUrl: galleryDetail.galleryUrl.url,
      uploader: galleryDetail.uploader,
      publishTime: galleryDetail.publishTime,
      languageAbbreviation: LocaleConsts.language2Abbreviation[galleryDetail.language]?.toLowerCase(),
      tagDatas: galleryDetail.tags.values.flattened.map((galleryTag) => galleryTag.tagData).toList(),
      rating: galleryDetail.realRating,
    );

    try {
      io.File file = io.File(path.join(computeGalleryDownloadAbsolutePath(gallery), 'ComicInfo.xml'));
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(galleryComicInfo.toXmlDocument().toXmlString(pretty: true));
    } catch (e) {
      log.error('Write comic info failed, gallery: ${gallery.gid}', e);
    }
  }

  void updateExecutor() {
    executor.concurrency = downloadSetting.downloadTaskConcurrency.value;
    executor.rate = Rate(downloadSetting.maximum.value, downloadSetting.period.value);
  }

  /// start executor
  void _startExecutor() {
    log.debug('start download executor');

    executor = EHExecutor(
      concurrency: downloadSetting.downloadTaskConcurrency.value,
      rate: Rate(downloadSetting.maximum.value, downloadSetting.period.value),
    );

    /// Resume gallery whose status is [downloading], order by insertTime
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        // gid2SpeedComputer[g.gid]!.start();
        downloadGallery(g, resume: true);
      }
    }
  }

  /// shutdown executor
  Future<void> _shutdownExecutor() async {
    log.info('Shutdown download executor');

    await pauseAllDownloadGallery();
    executor.close();
  }

  void _submitTask({
    required int gid,
    required int priority,
    required AsyncTask<void> task,
  }) {
    galleryDownloadInfos[gid]?.tasks.add(task);

    executor.scheduleTask(priority, task).then((_) => galleryDownloadInfos[gid]?.tasks.remove(task)).onError((e, stackTrace) {
      galleryDownloadInfos[gid]?.tasks.remove(task);
      if (e is! CancelException) {
        log.error('Executor exception!', e, stackTrace);
        log.uploadError(e);
      }
    });
  }

  /// Shortcut for the common pattern: compute image priority, build the task, submit.
  void _submitImageTask(GalleryDownloadedData gallery, int serialNo, AsyncTask<void> Function() taskBuilder) {
    return _submitTask(
      gid: gallery.gid,
      priority: _computeImageTaskPriority(gallery, serialNo),
      task: taskBuilder(),
    );
  }

  /// Rules:
  /// 1. If [downloadAllGallerysOfSamePriority] is false
  ///   1.1 Galleries download order:
  ///     1.1.1 gallery with high priority
  ///     1.1.2 gallery with low priority
  ///     1.1.3 if priority is same, download only 1 gallery simultaneously in the order of insert time ASC
  ///   1.2 For each gallery, previous image should be downloaded earlier
  /// 2. If [downloadAllGallerysOfSamePriority] is true
  ///   2.1 Galleries download order:
  ///     2.1.1 gallery with high priority
  ///     2.1.2 gallery with low priority
  ///     2.1.3 if priority is same, download all gallerys simultaneously
  ///   2.2 For each gallery, previous image should be downloaded earlier and images with same [serialNo] has the same priority no matter which gallery they belong to
  ///
  /// Because a gallery has most 2000 images, we assign 2000 numbers to each gallery
  int _computeGalleryTaskPriority(GalleryDownloadedData gallery) {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return 0;
    }

    int groupPriority = galleryDownloadInfos[gallery.gid]!.priority * _priorityBase;

    if (downloadSetting.downloadAllGallerysOfSamePriority.isTrue) {
      return groupPriority;
    }

    /// priority is same, order by insert time
    DateTime insertTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(gallery.insertTime);
    int timePriority = int.parse(DateFormat('MMddHHmmss').format(insertTime)) * 2000;

    return groupPriority + timePriority;
  }

  int _computeImageTaskPriority(GalleryDownloadedData gallery, int serialNo) {
    return _computeGalleryTaskPriority(gallery) + serialNo;
  }

  String _computeSanitizedGalleryTitle(String rawTitle, int reservedBytes) =>
      DownloadPathResolver.computeSanitizedGalleryTitle(rawTitle, reservedBytes);

  String computeGalleryDownloadAbsolutePath(GalleryDownloadedData gallery) =>
      DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery);

  String _computeImageDownloadAbsolutePath(GalleryDownloadedData gallery, String imageUrl, int serialNo) =>
      DownloadPathResolver.computeImageDownloadAbsolutePath(gallery, imageUrl, serialNo);

  String _computeImageDownloadRelativePath(GalleryDownloadedData gallery, String imageUrl, int serialNo) =>
      DownloadPathResolver.computeImageDownloadRelativePath(gallery, imageUrl, serialNo);

  static String computeImageDownloadAbsolutePathFromRelativePath(String imageRelativePath) =>
      DownloadPathResolver.computeImageDownloadAbsolutePathFromRelativePath(imageRelativePath);

  /// 'default' group always sorts last regardless of locale.
  int _groupSortRank(String group) => group == 'default'.tr ? 1 : 0;

  /// Sort a list of [GalleryDownloadedData] in place using the canonical
  /// order: group rank → group name → sortOrder → insertTime desc.
  void _sortGalleryData(List<GalleryDownloadedData> list) {
    list.sort((a, b) {
      GalleryDownloadInfo? aInfo = galleryDownloadInfos[a.gid];
      GalleryDownloadInfo? bInfo = galleryDownloadInfos[b.gid];
      if (aInfo == null || bInfo == null) {
        return 0;
      }

      final rankCmp = _groupSortRank(aInfo.group) - _groupSortRank(bInfo.group);
      if (rankCmp != 0) {
        return rankCmp;
      }

      final groupCmp = aInfo.group.compareTo(bInfo.group);
      if (groupCmp != 0) {
        return groupCmp;
      }

      final orderCmp = aInfo.sortOrder - bInfo.sortOrder;
      if (orderCmp != 0) {
        return orderCmp;
      }

      return b.insertTime.compareTo(a.insertTime);
    });
  }

  /// No-op retained for call-site compatibility. The [gallerys] getter now
  /// returns a freshly sorted snapshot on every access, so explicit re-sorts
  /// after mutation are unnecessary.
  void _sortGallerys() {}

  /// Pause one gallery or all galleries depending on [pauseAll].
  /// Centralizes the pause/pauseAll branch repeated across parse/download handlers.
  Future<void> _pauseOnSiteError({required GalleryDownloadedData gallery, required bool pauseAll, String? message}) {
    if (message != null) {
      snack('error'.tr, message, isShort: true);
    }
    return pauseAll ? pauseAllDownloadGallery() : pauseDownloadGallery(gallery);
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) {
    return galleryDownloadInfos[gallery.gid] == null || galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus == DownloadStatus.paused;
  }

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  bool taskHasBeenPausedOrRemoved(GalleryDownloadedData gallery) => _taskHasBeenPausedOrRemoved(gallery);

  bool _taskHasBeenRemoved(GalleryDownloadedData gallery) {
    return galleryDownloadInfos[gallery.gid] == null;
  }

  // Task

  AsyncTask<void> _downloadGalleryTask(GalleryDownloadedData gallery) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      /// If this is a update from old gallery, try to fetch image hashes from JHenTai Server
      if (gallery.oldVersionGalleryUrl != null && downloadSetting.useJH2UpdateGallery.isTrue) {
        List<String> imageHashes = await _fetchImageHashesFromJHenTaiServer(gallery);

        if (imageHashes.length == gallery.pageCount) {
          await _tryCopyImageInfosFromImageHashes(gallery, imageHashes);
        } else {
          log.error('Image hashes count mismatch, gid: ${gallery.gid}, expected: ${gallery.pageCount}, actual: ${imageHashes.length}');
        }
      }

      for (int serialNo = 0; serialNo < gallery.pageCount; serialNo++) {
        _processImage(gallery, serialNo);
      }
    };
  }

  Future<List<String>> _fetchImageHashesFromJHenTaiServer(GalleryDownloadedData gallery) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return [];
    }

    String? cachedImageHashes = await localConfigService.read(configKey: ConfigEnum.galleryImageHash, subConfigKey: gallery.gid.toString());
    if (cachedImageHashes != null) {
      return jsonDecode(cachedImageHashes).cast<String>();
    }

    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

    try {
      JHResponse response = await retry(
        () => jhRequest.requestGalleryImageHashes(
          gid: gallery.gid,
          token: gallery.token,
          cancelToken: galleryDownloadInfo.cancelToken,
          parser: JHResponseParser.commonParse,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => log.download('Failed to fetch image hashes, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _maxRetryTimes4FetchImageHashes,
      );

      log.debug('Fetch image hashes response: $response');
      if (response.isSuccess) {
        FetchImageHashesVO fetchImageHashesVO = FetchImageHashesVO.fromResponse(response.data);
        localConfigService.write(configKey: ConfigEnum.galleryImageHash, subConfigKey: gallery.gid.toString(), value: jsonEncode(fetchImageHashesVO.hashes));
        return fetchImageHashesVO.hashes;
      } else {
        return [];
      }
    } on DioException catch (e) {
      log.error('Failed to fetch image hashes', e.errorMsg, e.stackTrace);
      return [];
    } catch (e) {
      log.error('Failed to fetch image hashes', e.toString(), StackTrace.current);
      return [];
    }
  }

  Future<void> _processImage(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

    /// has downloaded this image => nothing to do
    if (galleryDownloadInfo.indexAt(serialNo)?.downloadStatus == DownloadStatus.downloaded) {
      return;
    }

    /// url has been parsed (DB row exists) => download directly
    if (galleryDownloadInfo.indexAt(serialNo) != null) {
      return _submitImageTask(gallery, serialNo, () => _downloadImageTask(gallery, serialNo));
    }

    /// has parsed href => parse url
    if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
      return _submitImageTask(gallery, serialNo, () => _parseImageUrlTask(gallery, serialNo));
    }

    /// has not parsed href => parse href
    _submitImageTask(gallery, serialNo, () => _parseImageHrefTask(gallery, serialNo));
  }

  AsyncTask<void> _parseImageHrefTask(GalleryDownloadedData gallery, int serialNo) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
      int requestPageIndex = serialNo ~/ galleryDownloadInfo.thumbnailsCountPerPage;

      DetailPageInfo detailPageInfo;
      try {
        detailPageInfo = await retry(
          () => ehRequest.requestDetailPage(
            galleryUrl: gallery.galleryUrl,
            thumbnailsPageIndex: requestPageIndex,
            cancelToken: galleryDownloadInfo.cancelToken,
            parser: EHSpiderParser.detailPage2RangeAndThumbnails,
          ),
          retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download('Parse image hrefs failed, retry. Reason: ${(e as DioException).toString()}'),
          maxAttempts: _maxRetryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        return _submitImageTask(gallery, serialNo, () => _parseImageHrefTask(gallery, serialNo));
      } on EHSiteException catch (e) {
        log.download('Parse image href error, reason: ${e.message}, gallery url: ${gallery.galleryUrl}');
        await _pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message);
        return;
      }

      /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
      /// For example, default setting is 40, but some gallerys' thumbnails has only high quality thumbnails, which results in 20.
      bool thumbnailsCountPerPageChanged = galleryDownloadInfo.thumbnailsCountPerPage != detailPageInfo.thumbnailsCountPerPage;
      galleryDownloadInfo.thumbnailsCountPerPage = detailPageInfo.thumbnailsCountPerPage;

      for (int i = detailPageInfo.imageNoFrom; i <= detailPageInfo.imageNoTo; i++) {
        galleryDownloadInfo.imageHrefs[i] = detailPageInfo.thumbnails[i - detailPageInfo.imageNoFrom];
      }

      /// if gallery's [thumbnailsCountPerPage] is not equal to default setting, we probably can't get target thumbnails this turn
      /// because the [thumbnailsPageIndex] we computed before is wrong, so we need to parse again
      if (galleryDownloadInfo.imageHrefs[serialNo] == null) {
        log.download(
          'Parse image hrefs error, thumbnails count per page is not equal to default setting, parse again. Thumbnails count per page: ${detailPageInfo.thumbnailsCountPerPage}, changed: $thumbnailsCountPerPageChanged',
        );
        await ehRequest.removeCacheByGalleryUrlAndPage(gallery.galleryUrl, requestPageIndex);
        return _submitImageTask(gallery, serialNo, () => _parseImageHrefTask(gallery, serialNo));
      }

      /// Next step: parse image url
      _submitImageTask(gallery, serialNo, () => _parseImageUrlTask(gallery, serialNo));
    };
  }

  AsyncTask<void> _parseImageUrlTask(GalleryDownloadedData gallery, int serialNo, {bool reParse = false, String? reloadKey}) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;

      /// If this is a update from old gallery, try to copy from existing old image first
      if (gallery.oldVersionGalleryUrl != null) {
        await _tryCopyImageInfoFromHref(gallery.oldVersionGalleryUrl!, gallery, serialNo);

        if (galleryDownloadInfo.indexAt(serialNo) != null) {
          return;
        }
      }

      GalleryImage image;
      try {
        image = await retry(
          () => ehRequest.requestImagePage(
            galleryDownloadInfo.imageHrefs[serialNo]!.replacedMPVHref(serialNo + 1),
            reloadKey: reloadKey,
            cancelToken: galleryDownloadInfo.cancelToken,
            useCacheIfAvailable: !reParse,
            parser: gallery.downloadOriginalImage && userSetting.hasLoggedIn()
                ? EHSpiderParser.imagePage2OriginalGalleryImage
                : EHSpiderParser.imagePage2GalleryImage,
          ),
          retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download('Parse image url failed, retry. Reason: ${(e as DioException).errorMsg}'),
          maxAttempts: _maxRetryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        return _submitImageTask(gallery, serialNo, () => _parseImageUrlTask(gallery, serialNo, reParse: true));
      } on EHParseException catch (e) {
        log.download('Parse image url error, reason: ${e.message.tr}');
        await _pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message.tr);

        ehRequest.removeCacheByUrl(galleryDownloadInfo.imageHrefs[serialNo]!.replacedMPVHref(serialNo + 1));

        return;
      } on EHSiteException catch (e) {
        log.download('Parse image url error, reason: ${e.message.tr}');
        await _pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message.tr);

        return;
      }

      image.path = _computeImageDownloadRelativePath(gallery, image.url, serialNo);
      image.downloadStatus = DownloadStatus.downloading;

      await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);

      galleryDownloadInfo.upsertImage(serialNo, image);

      log.download('Parse image url success, index: $serialNo, url: ${image.url}');

      /// Next step: download image
      return _submitImageTask(gallery, serialNo, () => _downloadImageTask(gallery, serialNo));
    };
  }

  AsyncTask<void> _downloadImageTask(GalleryDownloadedData gallery, int serialNo) {
    return () async {
      if (_taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = galleryDownloadInfos[gallery.gid]!;
      GalleryImage image = galleryDownloadInfo.imageAtSync(serialNo) ?? (await galleryDownloadInfo.imageAt(serialNo))!;

      _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloading);

      /// If this is a update from old gallery, try to copy from existing old image first
      if (gallery.oldVersionGalleryUrl != null) {
        await _tryCopyImageInfoFromImage(gallery.oldVersionGalleryUrl!, gallery, serialNo);

        if (image.downloadStatus == DownloadStatus.downloaded) {
          return;
        }
      }

      String path = _computeImageDownloadAbsolutePath(gallery, image.url, serialNo);

      await _tryLoadFromCacheInsteadDownload(gallery, image, serialNo, path);
      if (image.downloadStatus == DownloadStatus.downloaded) {
        return;
      }

      Response response;
      try {
        response = await retry(
          () => ehRequest.download(
            url: image.url,
            path: path,
            receiveTimeout: 3 * 60 * 1000,
            cancelToken: galleryDownloadInfo.cancelToken,
            onReceiveProgress: (int count, int total) => galleryDownloadInfo.speedComputer.updateProgress(count, total, serialNo),
          ),
          maxAttempts: _maxRetryTimes,

          /// 403 is due to broken H@H node, we should re-parse
          /// If we have not downloaded any bytes, we should re-parse because we might encounter a death H@H node
          retryIf: (e) =>
              e is DioException &&
              e.type != DioExceptionType.cancel &&
              (e.response == null || e.response!.statusCode != 403) &&
              galleryDownloadInfo.speedComputer.getImageDownloadedBytes(serialNo) > 0,
          onRetry: (e) {
            log.download('Download ${gallery.title} image: $serialNo failed, retry. Reason: ${(e as DioException).errorMsg}. Url:${image.url}');
            galleryDownloadInfo.speedComputer.resetProgress(serialNo);
          },
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        log.download('Download ${gallery.title} image: $serialNo failed, try re-parse. Reason: ${e.errorMsg}. Url:${image.url}');
        return _reParseImageUrlAndDownload(gallery, serialNo);
      } on EHSiteException catch (e) {
        log.download('Download Error, reason: ${e.message}');
        await _pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message);
        return;
      }

      /// what we downloaded is not an valid image
      if (!response.isRedirect && (response.headers[Headers.contentTypeHeader]?.contains("text/html; charset=UTF-8") ?? false)) {
        String data = io.File(path).readAsStringSync();

        EHImageException? exception = imageData2Exception(data);
        log.error('Download ${gallery.title} image: $serialNo failed: $exception');

        if (exception != null) {
          if (exception.operation == EHImageExceptionAfterOperation.reParse) {
            return _reParseImageUrlAndDownload(gallery, serialNo);
          }
          return _pauseOnSiteError(
            gallery: gallery,
            pauseAll: exception.operation == EHImageExceptionAfterOperation.pauseAll,
            message: exception.message,
          );
        }
        return _pauseOnSiteError(gallery: gallery, pauseAll: false, message: 'downloadFailed'.tr);
      }

      log.download('Download ${gallery.title} image: $serialNo success');

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

    String? reloadKey = galleryDownloadInfo.imageAtSync(serialNo)?.reloadKey;
    galleryDownloadInfo.clearImage(serialNo);
    await GalleryImageDao.deleteImage(gallery.gid, serialNo);

    /// has parsed href => parse url
    if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
      return _submitImageTask(gallery, serialNo, () => _parseImageUrlTask(gallery, serialNo, reParse: true, reloadKey: reloadKey));
    } 

    /// has not parsed href => parse href
    return _submitImageTask(gallery, serialNo, () => _parseImageHrefTask(gallery, serialNo));
  }


  Future<void> _tryCopyImageInfosFromImageHashes(GalleryDownloadedData newGallery, List<String> imageHashes) =>
      _upgradeMigrator.copyImageInfosFromImageHashes(newGallery, imageHashes);

  Future<void> _tryCopyImageInfoFromHref(String oldVersionGalleryUrl, GalleryDownloadedData newGallery, int newImageSerialNo) =>
      _upgradeMigrator.tryCopyImageInfoFromHref(oldVersionGalleryUrl, newGallery, newImageSerialNo);

  Future<void> _tryCopyImageInfoFromImage(String oldVersionGalleryUrl, GalleryDownloadedData newGallery, int newImageSerialNo) =>
      _upgradeMigrator.tryCopyImageInfoFromImage(oldVersionGalleryUrl, newGallery, newImageSerialNo);

  Future<void> _tryLoadFromCacheInsteadDownload(GalleryDownloadedData gallery, GalleryImage image, int serialNo, String path) async {
    io.File? cachedImageFile = await getCachedImageFile(image.url);
    if (cachedImageFile != null && cachedImageFile.existsSync()) {
      log.debug('download image from cache, gallery: ${gallery.gid}, serialNo:$serialNo');
      await cachedImageFile.copy(path);
      await _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloaded);
      await _updateProgressAfterImageDownloaded(gallery, serialNo);
    }
  }

  Future<void> _updateProgressAfterImageDownloaded(GalleryDownloadedData gallery, int serialNo) async {
    if (_taskHasBeenRemoved(gallery)) {
      return;
    }

    GalleryDownloadProgress downloadProgress = galleryDownloadInfos[gallery.gid]!.downloadProgress;
    downloadProgress.curCount++;
    downloadProgress.hasDownloaded[serialNo] = true;

    if (downloadProgress.curCount == downloadProgress.totalCount) {
      downloadProgress.downloadStatus = DownloadStatus.downloaded;
      await _updateGalleryDownloadStatus(gallery, DownloadStatus.downloaded);
      galleryDownloadInfos[gallery.gid]!.speedComputer.dispose();
      /// All images downloaded — evict the full-data cache. Index is retained
      /// for cover/list/detail access; full data re-loads on next read page open.
      galleryDownloadInfos[gallery.gid]!.evictImagesCache();
      update(['$galleryDownloadSuccessId::${gallery.gid}']);
    }

    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  Future<void> updateProgressAfterImageDownloaded(GalleryDownloadedData gallery, int serialNo) =>
      _updateProgressAfterImageDownloaded(gallery, serialNo);

  Future<void> _instantiateFromDB() async {
    allGroups = (await GalleryGroupDao.selectGalleryGroups()).map((e) => e.groupName).toList();
    log.debug('init Gallery groups: $allGroups');

    /// Get download info from database
    List<GalleryDownloadedData> dbGallerys = await GalleryDao.selectGallerys();

    /// Only load cover indices (serialNo=0) at startup — full image indices
    /// lazy-load on first access to each gallery (detail/read/download).
    Map<int, GalleryImageIndex> coverIndices = await GalleryImageDao.selectCoverIndices();
    Map<int, int> downloadedCounts = await GalleryImageDao.selectDownloadedCountsByGid();

    for (GalleryDownloadedData gallery in dbGallerys) {
      /// Instantiate [Gallery] with an empty index list; we'll fill slot 0 below.
      _initGalleryInfoInMemory(gallery, sort: false);

      GalleryDownloadInfo info = galleryDownloadInfos[gallery.gid]!;

      /// Populate cover index (slot 0) if a DB row exists.
      GalleryImageIndex? cover = coverIndices[gallery.gid];
      if (cover != null) {
        info.imageIndices[0] = cover;
        if (cover.downloadStatus == DownloadStatus.downloaded) {
          /// Cover counts toward curCount only if it's downloaded.
        }
      }

      /// Populate curCount: for fully-downloaded galleries, it equals pageCount;
      /// otherwise use the precise count from DB. hasDownloaded stays all-false
      /// (lazy-loaded with full indices on first access).
      int downloadedCount = downloadedCounts[gallery.gid] ?? 0;
      if (gallery.downloadStatusIndex == DownloadStatus.downloaded.index) {
        info.downloadProgress.curCount = gallery.pageCount;
        info.downloadProgress.hasDownloaded = List.generate(gallery.pageCount, (_) => true);
      } else {
        info.downloadProgress.curCount = downloadedCount;
        /// hasDownloaded stays default (all false) — will be synced when
        /// ensureImageIndicesLoaded() runs on first access.
      }
    }

    // sort after instantiated
    _sortGallerys();
  }

  Future<GalleryDownloadedData?> _initGalleryInfo(GalleryDownloadedData gallery) async {
    /// Compute and attach the sanitized title before the first DB write so the
    /// path is frozen for the lifetime of this download task.
    final int reservedBytes = utf8.encode('${gallery.gid} - ').length;
    gallery = gallery.copyWith(sanitizedTitle: Value(_computeSanitizedGalleryTitle(gallery.title, reservedBytes)));

    if (!await _saveGalleryInfoAndGroupInDB(gallery)) {
      return null;
    }

    _initGalleryInfoInMemory(gallery);

    _saveGalleryMetadataInDisk(gallery);

    return gallery;
  }

  Future<void> _updateGalleryDownloadStatus(GalleryDownloadedData gallery, DownloadStatus downloadStatus) async {
    await _updateGalleryInDatabase(
      GalleryDownloadedCompanion(gid: Value(gallery.gid), downloadStatusIndex: Value(downloadStatus.index)),
    );

    galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus = downloadStatus;

    _saveGalleryMetadataInDisk(gallery);
  }

  Future<bool> _updateImageStatus(GalleryDownloadedData gallery, GalleryImage image, int serialNo, DownloadStatus downloadStatus) async {
    if (!await _updateImageInDatabase(
      ImageCompanion(gid: Value(gallery.gid), serialNo: Value(serialNo), downloadStatusIndex: Value(downloadStatus.index)),
    )) {
      return false;
    }

    image.downloadStatus = downloadStatus;

    update(['$downloadImageId::${gallery.gid}::$serialNo', '$downloadImageUrlId::${gallery.gid}::$serialNo']);

    _saveGalleryMetadataInDisk(gallery);

    return true;
  }

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  Future<bool> updateImageStatus(GalleryDownloadedData gallery, GalleryImage image, int serialNo, DownloadStatus downloadStatus) =>
      _updateImageStatus(gallery, image, serialNo, downloadStatus);

  Future<bool> _addGroup(String group) async {
    if (!allGroups.contains(group)) {
      allGroups.add(group);
    }

    return (await GalleryGroupDao.insertGalleryGroup(GalleryGroupData(groupName: group, sortOrder: 0)) > 0);
  }

  Future<bool> _deleteGroup(String group) async {
    allGroups.remove(group);

    try {
      return (await GalleryGroupDao.deleteGalleryGroup(group) > 0);
    } on SqliteException catch (e) {
      log.info(e);
      return false;
    }
  }

  // MEMORY

  void _initGalleryInfoInMemory(GalleryDownloadedData gallery, {List<GalleryImageIndex?>? imageIndices, bool sort = true}) {
    if (!allGroups.contains(gallery.groupName)) {
      allGroups.add(gallery.groupName);
    }
    galleryDownloadInfos[gallery.gid] = GalleryDownloadInfo(
      gid: gallery.gid,
      token: gallery.token,
      galleryUrl: gallery.galleryUrl,
      title: gallery.title,
      category: gallery.category,
      pageCount: gallery.pageCount,
      uploader: gallery.uploader,
      publishTime: gallery.publishTime,
      insertTime: gallery.insertTime,
      oldVersionGalleryUrl: gallery.oldVersionGalleryUrl,
      sanitizedTitle: gallery.sanitizedTitle,
      priority: gallery.priority,
      sortOrder: gallery.sortOrder,
      group: gallery.groupName,
      downloadOriginalImage: gallery.downloadOriginalImage,
      tags: gallery.tags,
      tagRefreshTime: gallery.tagRefreshTime,
      thumbnailsCountPerPage: SiteSetting.thumbnailsCountPerPage.value,
      tasks: [],
      cancelToken: CancelToken(),
      downloadProgress: GalleryDownloadProgress(
        curCount: imageIndices?.fold<int>(0, (total, idx) => total + (idx?.downloadStatus == DownloadStatus.downloaded ? 1 : 0)) ?? 0,
        totalCount: gallery.pageCount,
        downloadStatus: DownloadStatus.values[gallery.downloadStatusIndex],
        hasDownloaded: imageIndices?.map((idx) => idx?.downloadStatus == DownloadStatus.downloaded).toList() ?? List.generate(gallery.pageCount, (_) => false),
      ),
      imageHrefs: List.generate(gallery.pageCount, (_) => null),
      imageIndices: imageIndices ?? List.generate(gallery.pageCount, (_) => null),
      onSpeedUpdate: () => update(['$galleryDownloadSpeedComputerId::${gallery.gid}']),
    );

    if (sort) {
      _sortGallerys();
    }

    update([galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryInfoInMemory(GalleryDownloadedData gallery) {
    _metadataStore.cancel(gallery.gid);
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadInfos.remove(gallery.gid);
    galleryDownloadInfo?._speedComputer?.dispose();

    update([galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  // DB

  Future<bool> _saveGalleryInfoAndGroupInDB(GalleryDownloadedData gallery) async {
    return appDb.transaction(() async {
      await GalleryGroupDao.insertGalleryGroup(GalleryGroupData(groupName: gallery.groupName, sortOrder: 0));

      return await GalleryDao.insertGallery(
            GalleryDownloadedCompanion.insert(
              gid: Value(gallery.gid),
              token: gallery.token,
              title: gallery.title,
              category: gallery.category,
              pageCount: gallery.pageCount,
              galleryUrl: gallery.galleryUrl,
              oldVersionGalleryUrl: Value(gallery.oldVersionGalleryUrl),
              uploader: Value(gallery.uploader),
              publishTime: gallery.publishTime,
              downloadStatusIndex: gallery.downloadStatusIndex,
              insertTime: gallery.insertTime,
              downloadOriginalImage: Value(gallery.downloadOriginalImage),
              priority: gallery.priority,
              sortOrder: Value(gallery.sortOrder),
              groupName: gallery.groupName,
              tags: Value(gallery.tags),
              tagRefreshTime: Value(gallery.tagRefreshTime),
              sanitizedTitle: Value(gallery.sanitizedTitle),
            ),
          ) >
          0;
    });
  }

  Future<bool> _saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) async {
    return await GalleryImageDao.insertImage(
          ImageData(
            gid: gid,
            serialNo: serialNo,
            url: image.url,
            path: image.path!,
            imageHash: image.imageHash ?? '',
            downloadStatusIndex: image.downloadStatus.index,
          ),
        ) >
        0;
  }

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  Future<bool> saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) =>
      _saveNewImageInfoInDatabase(image, serialNo, gid);

  Future<bool> _updateGalleryInDatabase(GalleryDownloadedCompanion gallery) async {
    return await GalleryDao.updateGallery(gallery) > 0;
  }

  Future<bool> _updateImageInDatabase(ImageCompanion image) async {
    return await GalleryImageDao.updateImage(image) > 0;
  }

  Future<void> _clearGalleryDownloadInfoInDatabase(int gid) {
    return appDb.transaction(() async {
      await GalleryImageDao.deleteImagesWithGid(gid);
      await GalleryDao.deleteGallery(gid);
    });
  }

  Future<bool> _restoreInfoInDatabase(GalleryDownloadedData gallery, List<GalleryImage?> images) async {
    if (gallery.downloadStatusIndex == DownloadStatus.downloading.index) {
      gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
    }

    if (!await _saveGalleryInfoAndGroupInDB(gallery)) {
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
      log.error('Restore images into database error}', e);
      log.uploadError(e);
      return false;
    });
  }

  // Disk

  /// Per-gallery metadata JSON persistence (debounced writes + disk reads for restore).
  late final GalleryMetadataStore _metadataStore = GalleryMetadataStore(this);

  /// Gallery upgrade migration: copy image bytes + metadata from an old gallery
  /// version to a new one by matching imageHash.
  late final GalleryUpgradeMigrator _upgradeMigrator = GalleryUpgradeMigrator(this);

  void _saveGalleryMetadataInDisk(GalleryDownloadedData gallery) => _metadataStore.save(gallery);

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  void saveGalleryMetadataInDisk(GalleryDownloadedData gallery) => _metadataStore.save(gallery);

  Future<void> _flushMetadataSave(GalleryDownloadedData gallery) => _metadataStore.flush(gallery);

  void _clearDownloadedImageInDisk(GalleryDownloadedData gallery) {
    io.Directory directory = io.Directory(computeGalleryDownloadAbsolutePath(gallery));
    if (!directory.existsSync()) {
      return;
    }
    directory.deleteSync(recursive: true);
  }

  void _deleteImageInDisk(GalleryImage image) {
    try {
      io.File file = io.File(image.path!);
      if (!file.existsSync()) {
        return;
      }
      file.deleteSync();
    } on Exception catch (e) {
      log.error('Delete image in disk error', e);
      log.uploadError(e);
    }
  }

  void _ensureDownloadDirExists() {
    try {
      io.Directory(downloadSetting.downloadPath.value).createSync(recursive: true);
    } on Exception catch (e) {
      toast('brokenDownloadPathHint'.tr);
      log.error(e);
      log.uploadError(
        e,
        extraInfos: {
          'defaultDownloadPath': downloadSetting.defaultDownloadPath,
          'downloadPath': downloadSetting.downloadPath.value,
          'exists': pathService.getVisibleDir().existsSync(),
        },
      );
    }
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
  // === Identity (immutable after creation) ===
  final int gid;
  final String token;
  final String galleryUrl;
  final String title;
  final String category;
  final int pageCount;
  final String? uploader;
  final String publishTime;
  final String insertTime;
  final String? oldVersionGalleryUrl;
  final String? sanitizedTitle;

  // === Mutable config (user-changeable) ===
  int priority;
  int sortOrder;
  String group;
  bool downloadOriginalImage;
  String tags;
  String? tagRefreshTime;

  // === Download runtime state ===
  GalleryDownloadProgress downloadProgress;
  /// 20, 40 and so on
  int thumbnailsCountPerPage;
  List<AsyncTask> tasks;
  CancelToken cancelToken;
  List<GalleryThumbnail?> imageHrefs;

  /// Two-tier image data: always-resident index + lazy-evictable full-data cache.
  late final GalleryImageCache imageCache;

  /// Lazily allocated so completed/restored galleries don't pay the cost of
  /// per-image byte-tracking lists until a download actually (re)starts.
  GalleryDownloadSpeedComputer? _speedComputer;
  final VoidCallback _onSpeedUpdate;
  GalleryDownloadSpeedComputer get speedComputer =>
      _speedComputer ??= GalleryDownloadSpeedComputer(pageCount, _onSpeedUpdate);

  GalleryDownloadInfo({
    required this.gid,
    required this.token,
    required this.galleryUrl,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.thumbnailsCountPerPage,
    required this.tasks,
    required this.cancelToken,
    required this.downloadProgress,
    required this.imageHrefs,
    List<GalleryImageIndex?>? imageIndices,
    required this.priority,
    required this.sortOrder,
    required this.group,
    required this.downloadOriginalImage,
    required this.tags,
    required this.tagRefreshTime,
    this.uploader,
    required this.publishTime,
    required this.insertTime,
    this.oldVersionGalleryUrl,
    this.sanitizedTitle,
    required VoidCallback onSpeedUpdate,
  }) : _onSpeedUpdate = onSpeedUpdate {
    imageCache = GalleryImageCache(
      gid: gid,
      pageCount: pageCount,
      downloadProgress: downloadProgress,
      initialIndices: imageIndices,
    );
  }

  // === Image access delegates to [imageCache] ===
  List<GalleryImageIndex?> get imageIndices => imageCache.imageIndices;
  GalleryImageIndex? indexAt(int serialNo) => imageCache.indexAt(serialNo);
  Future<void> ensureImageIndicesLoaded() => imageCache.ensureImageIndicesLoaded();
  Future<void> ensureImagesCacheLoaded() => imageCache.ensureImagesCacheLoaded();
  void evictImagesCache() => imageCache.evictImagesCache();
  Future<GalleryImage?> imageAt(int serialNo) => imageCache.imageAt(serialNo);
  GalleryImage? imageAtSync(int serialNo) => imageCache.imageAtSync(serialNo);
  void upsertImage(int serialNo, GalleryImage image) => imageCache.upsertImage(serialNo, image);
  void updateImageStatus(int serialNo, DownloadStatus status) => imageCache.updateImageStatus(serialNo, status);
  void updateImagePath(int serialNo, String? newPath) => imageCache.updateImagePath(serialNo, newPath);
  void clearImage(int serialNo) => imageCache.clearImage(serialNo);

  /// Synthesize a [GalleryDownloadedData] view from the absorbed fields.
  /// Used where external code / DB layer still expects the DataClass shape.
  GalleryDownloadedData toGalleryDownloadedData() => GalleryDownloadedData(
        gid: gid,
        token: token,
        title: title,
        category: category,
        pageCount: pageCount,
        galleryUrl: galleryUrl,
        oldVersionGalleryUrl: oldVersionGalleryUrl,
        uploader: uploader,
        publishTime: publishTime,
        downloadStatusIndex: downloadProgress.downloadStatus.index,
        insertTime: insertTime,
        downloadOriginalImage: downloadOriginalImage,
        priority: priority,
        sortOrder: sortOrder,
        groupName: group,
        tags: tags,
        tagRefreshTime: tagRefreshTime,
        sanitizedTitle: sanitizedTitle,
      );
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

  int getImageDownloadedBytes(int serialNo) {
    return imageDownloadedBytes[serialNo];
  }
}
