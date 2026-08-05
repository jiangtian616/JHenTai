import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:executor/executor.dart';
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
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

import '../../consts/locale_consts.dart';
import '../../database/dao/gallery_image_dao.dart';
import '../../exception/cancel_exception.dart';
import '../../exception/eh_site_exception.dart';
import 'download_path_resolver.dart';
import 'gallery_image_cache.dart';
import 'gallery_metadata_store.dart';
import 'gallery_download_task_runner.dart';
import 'gallery_upgrade_migrator.dart';
import '../../model/comic_info.dart';
import '../../model/gallery_detail.dart';
import '../../model/gallery_image.dart';
import '../../network/eh_request.dart';
import '../../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../../utils/eh_executor.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/snack_util.dart';
import '../jh_service.dart';
import '../path_service.dart';

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

  /// Cached sorted snapshot of [galleryDownloadInfos]. Invalidated on any
  /// mutation that affects order (add / delete / group rename / group change
  /// / priority change). Re-sorted on next read. Avoids O(N log N) per UI
  /// rebuild — critical for thousands-of-galleries scenarios.
  List<GalleryDownloadInfo>? _gallerysCache;

  /// Sorted view synthesized from [galleryDownloadInfos]. Single source of
  /// truth — the map holds the data; this getter returns a cached sorted
  /// snapshot, rebuilt only when the set or order-affecting fields change.
  List<GalleryDownloadInfo> get gallerys {
    return _gallerysCache ??= _rebuildGallerysCache();
  }

  List<GalleryDownloadInfo> _rebuildGallerysCache() {
    final list = galleryDownloadInfos.values.toList();
    list.sort();
    return list;
  }

  /// Invalidate the sorted cache. Call after any mutation that could affect
  /// order or membership: add, delete, group change, group rename, priority
  /// change. (sortOrder/insertTime are immutable post-creation.)
  void _invalidateGallerysCache() {
    _gallerysCache = null;
  }

  /// Filter galleries by group from the cached sorted [gallerys] list —
  /// result preserves the canonical sort order. O(N) walk of the cache,
  /// no extra sort.
  List<GalleryDownloadInfo> gallerysWithGroup(String group) {
    return gallerys.where((g) => g.group == group).toList();
  }

  static const int _maxRetryTimes = 3;
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

  Future<void> downloadGallery(GalleryDownloadRequest request) async {
    if (containGallery(request.gid)) {
      return;
    }

    _ensureDownloadDirExists();

    GalleryDownloadedData gallery = _toGalleryDownloadedData(request, DownloadStatus.downloading);

    GalleryDownloadedData? galleryWithSanitizedTitle = await _initGalleryInfo(gallery);
    if (galleryWithSanitizedTitle == null) {
      return;
    }
    gallery = galleryWithSanitizedTitle;

    _generateComicInfoInDisk(galleryDownloadInfos[gallery.gid]!);

    await _startDownloadTask(galleryDownloadInfos[gallery.gid]!);

    log.info('Begin to download gallery: ${gallery.title}, original: ${gallery.downloadOriginalImage}');
  }

  /// Resume a paused download. The [GalleryDownloadInfo] must already exist.
  Future<void> _resumeDownloadGallery(int gid) async {
    await _startDownloadTask(galleryDownloadInfos[gid]!);
  }

  Future<void> _startDownloadTask(GalleryDownloadInfo info) async {
    info.speedComputer.start();

    /// Pre-load full imagesCache so synchronous reads during download (e.g.
    /// `_downloadImageTask` reading `image.url`) work without per-call awaits.
    await info.ensureImagesCacheLoaded();

    _submitTask(
      gid: info.gid,
      priority: _computeGalleryTaskPriority(info),
      task: GalleryDownloadTaskRunner(this, info).downloadGalleryTask(),
    );
  }

  /// Convert a [GalleryDownloadRequest] BO to the DB-row shape for internal
  /// persistence. Status, sortOrder, insertTime, and priority are service-
  /// owned — callers cannot set them.
  GalleryDownloadedData _toGalleryDownloadedData(GalleryDownloadRequest request, DownloadStatus status) {
    return GalleryDownloadedData(
      gid: request.gid,
      token: request.token,
      title: request.title,
      category: request.category,
      pageCount: request.pageCount,
      galleryUrl: request.galleryUrl,
      oldVersionGalleryUrl: request.oldVersionGalleryUrl,
      uploader: request.uploader,
      publishTime: request.publishTime,
      downloadStatusIndex: status.index,
      insertTime: DateTime.now().toString(),
      downloadOriginalImage: request.downloadOriginalImage,
      priority: request.priority ?? defaultDownloadGalleryPriority,
      sortOrder: request.sortOrder ?? 0,
      groupName: request.group,
      tags: request.tags,
      tagRefreshTime: request.tagRefreshTime,
    );
  }

  Future<void> pauseAllDownloadGallery() async {
    /// Snapshot the downloading galleries — pauseDownloadGallery mutates
    /// `downloadProgress.downloadStatus` mid-iteration, so we can't filter
    /// lazily against the live map.
    final downloading = galleryDownloadInfos.values
        .where((g) => g.downloadProgress.downloadStatus == DownloadStatus.downloading)
        .toList();
    if (downloading.isEmpty) return;

    /// Single transaction: bulk gallery status + bulk image status.
    /// Avoids N per-gallery DB round-trips (one UPDATE + one image-batch
    /// UPDATE per gallery × thousands of galleries).
    await appDb.transaction(() async {
      await GalleryDao.batchUpdateGallery(
        downloading
            .map((g) => GalleryDownloadedCompanion(
                  gid: Value(g.gid),
                  downloadStatusIndex: Value(DownloadStatus.paused.index),
                ))
            .toList(),
      );
      await GalleryImageDao.updateImageStatusByGids(
        downloading.map((g) => g.gid),
        DownloadStatus.downloading.index,
        DownloadStatus.paused.index,
      );
    });

    /// In-memory + UI updates per gallery. No further DB writes here.
    for (final gallery in downloading) {
      final info = galleryDownloadInfos[gallery.gid]!;
      info.downloadProgress.downloadStatus = DownloadStatus.paused;

      for (AsyncTask task in info.tasks) {
        executor.cancelTask(task);
      }
      info.tasks.clear();
      info.cancelToken.cancel();
      info.speedComputer.pause();

      for (GalleryImageIndex? idx in info.imageIndices) {
        if (idx?.downloadStatus == DownloadStatus.downloading) {
          idx?.downloadStatus = DownloadStatus.paused;
          update(['$downloadImageId::${gallery.gid}']);
        }
      }

      await _flushMetadataSave(gallery);
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }
  }

  GalleryDownloadInfo? _findGalleryByGid(int gid) => galleryDownloadInfos[gid];

  Future<void> pauseDownloadGalleryByGid(int gid) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return pauseDownloadGallery(gallery);
    }
  }

  Future<void> pauseDownloadGallery(GalleryDownloadInfo gallery) async {
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

    /// Persist per-image paused status so a restart doesn't leave stale
    /// `downloading` rows on a paused gallery — the in-memory coercion below
    /// would otherwise be lost on `_instantiateFromDB`'s DB read.
    await GalleryImageDao.updateImageStatusByGallery(
      gallery.gid,
      DownloadStatus.downloading.index,
      DownloadStatus.paused.index,
    );

    for (GalleryImageIndex? idx in galleryDownloadInfo.imageIndices) {
      if (idx?.downloadStatus == DownloadStatus.downloading) {
        idx?.downloadStatus = DownloadStatus.paused;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    await _flushMetadataSave(gallery);

    log.info('Pause download gallery: ${gallery.title}');
  }

  Future<void> resumeAllDownloadGallery() async {
    final paused = galleryDownloadInfos.values
        .where((g) => g.downloadProgress.downloadStatus == DownloadStatus.paused)
        .toList();
    if (paused.isEmpty) return;

    /// Single transaction: bulk gallery status + bulk image status.
    await appDb.transaction(() async {
      await GalleryDao.batchUpdateGallery(
        paused
            .map((g) => GalleryDownloadedCompanion(
                  gid: Value(g.gid),
                  downloadStatusIndex: Value(DownloadStatus.downloading.index),
                ))
            .toList(),
      );
      await GalleryImageDao.updateImageStatusByGids(
        paused.map((g) => g.gid),
        DownloadStatus.paused.index,
        DownloadStatus.downloading.index,
      );
    });

    for (final gallery in paused) {
      final info = galleryDownloadInfos[gallery.gid]!;
      info.downloadProgress.downloadStatus = DownloadStatus.downloading;

      /// can't reuse cancelToken across pause/resume
      info.cancelToken = CancelToken();
      info.speedComputer.start();

      for (GalleryImageIndex? idx in info.imageIndices) {
        if (idx?.downloadStatus == DownloadStatus.paused) {
          idx?.downloadStatus = DownloadStatus.downloading;
          update(['$downloadImageId::${gallery.gid}']);
        }
      }

      _saveGalleryMetadataInDisk(gallery);
      update(['$galleryDownloadProgressId::${gallery.gid}']);

      /// Re-submit the gallery task — single-launch, no per-image await needed.
      _submitTask(
        gid: info.gid,
        priority: _computeGalleryTaskPriority(info),
        task: GalleryDownloadTaskRunner(this, info).downloadGalleryTask(),
      );
    }
  }

  Future<void> resumeDownloadGalleryByGid(int gid) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return resumeDownloadGallery(gallery);
    }
  }

  Future<void> resumeDownloadGallery(GalleryDownloadInfo gallery) async {
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

    /// Mirror the pause-time batch write: flip persisted `paused` rows back to
    /// `downloading` so the DB matches in-memory state.
    await GalleryImageDao.updateImageStatusByGallery(
      gallery.gid,
      DownloadStatus.paused.index,
      DownloadStatus.downloading.index,
    );

    for (GalleryImageIndex? idx in galleryDownloadInfo.imageIndices) {
      if (idx?.downloadStatus == DownloadStatus.paused) {
        idx?.downloadStatus = DownloadStatus.downloading;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    log.info('Resume download gallery: ${gallery.title}');

    _saveGalleryMetadataInDisk(gallery);

    _resumeDownloadGallery(gallery.gid);
  }

  Future<void> deleteGalleryByGid(int gid) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return deleteGallery(gallery);
    }
  }

  Future<void> deleteGallery(GalleryDownloadInfo gallery, {bool deleteImages = true}) async {
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
  Future<void> updateGallery(GalleryDownloadInfo oldGallery, GalleryUrl newVersionGalleryUrl) async {
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

    GalleryDownloadRequest newGalleryRequest = GalleryDownloadRequest(
      gid: newGalleryDetail.galleryUrl.gid,
      token: newGalleryDetail.galleryUrl.token,
      title: newGalleryDetail.japaneseTitle ?? newGalleryDetail.rawTitle,
      category: newGalleryDetail.category,
      pageCount: newGalleryDetail.pageCount,
      galleryUrl: newGalleryDetail.galleryUrl.url,
      uploader: newGalleryDetail.uploader,
      publishTime: newGalleryDetail.publishTime,
      downloadOriginalImage: oldGallery.downloadOriginalImage,
      group: oldGallery.group,
      tags: tagMap2TagString(newGalleryDetail.tags),
      tagRefreshTime: DateTime.now().toString(),
      oldVersionGalleryUrl: oldGallery.galleryUrl,
    );

    downloadGallery(newGalleryRequest);
  }

  Future<void> importGallery(GalleryDownloadRequest request, List<GalleryImage> images) async {
    if (containGallery(request.gid)) {
      return;
    }

    log.info('Import gallery: ${request.title}');

    _ensureDownloadDirExists();

    GalleryDownloadedData gallery = _toGalleryDownloadedData(request, DownloadStatus.downloaded);

    io.Directory galleryDir = io.Directory(DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery));
    if (!galleryDir.existsSync()) {
      galleryDir.createSync(recursive: true);
    }

    List<Future> futures = [];
    List<GalleryImage> copiedImages = [];
    for (int i = 0; i < images.length; i++) {
      GalleryImage image = images[i];
      String oldPath = DownloadPathResolver.computeImageDownloadAbsolutePathFromRelativePath(image.path!);
      String newPath = DownloadPathResolver.computeImageDownloadAbsolutePath(gallery, image.url, i);
      futures.add(io.File(oldPath).copy(newPath));

      copiedImages.add(image.copyWith(path: DownloadPathResolver.computeImageDownloadRelativePath(gallery, image.url, i)));
    }

    await Future.wait(futures);

    if (!await _restoreInfoInDatabase(gallery, copiedImages)) {
      log.error('Import gallery failed: ${gallery.title}');
      _clearGalleryDownloadInfoInDatabase(gallery.gid);
      return;
    }

    _initGalleryInfoInMemoryWithIndices(
      gallery,
      copiedImages
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

    _saveGalleryMetadataInDisk(galleryDownloadInfos[gallery.gid]!);
  }

  Future<void> reDownloadGalleryByGid(int gid) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return reDownloadGallery(gallery);
    }
  }

  Future<void> reDownloadGallery(GalleryDownloadInfo gallery) async {
    log.info('Re-download gallery: ${gallery.gid}');

    GalleryDownloadRequest request = gallery.toGalleryDownloadRequest();
    await deleteGallery(gallery);

    downloadGallery(request);
  }

  Future<void> reDownloadImage(int gid, int serialNo) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
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

    GalleryDownloadTaskRunner(this, gallery).reParseImageUrlAndDownload(serialNo);
  }

  Future<void> assignPriority(GalleryDownloadInfo gallery, int priority) async {
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
    _invalidateGallerysCache();

    if (galleryDownloadInfos[gallery.gid]?.downloadProgress.downloadStatus == DownloadStatus.downloading) {
      await pauseDownloadGallery(gallery);
      await resumeDownloadGallery(gallery);
    }
  }

  Future<bool> updateGroupByGid(int gid, String group) async {
    GalleryDownloadInfo? gallery = _findGalleryByGid(gid);
    if (gallery != null) {
      return updateGroup(gallery, group);
    }
    return false;
  }

  Future<bool> updateGroup(GalleryDownloadInfo gallery, String group) async {
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
    _invalidateGallerysCache();
    _saveGalleryMetadataInDisk(gallery);

    return true;
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    List<GalleryDownloadInfo> gallerysInGroup = gallerysWithGroup(oldGroup);

    await appDb.transaction(() async {
      if (!allGroups.contains(newGroup) && !await _addGroup(newGroup)) {
        return;
      }

      for (GalleryDownloadInfo g in gallerysInGroup) {
        g.group = newGroup;
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(g.gid), groupName: Value(newGroup)),
        );
        _saveGalleryMetadataInDisk(g);
      }

      await _deleteGroup(oldGroup);
    });

    _invalidateGallerysCache();
  }

  Future<void> deleteGroup(String group) {
    return _deleteGroup(group);
  }

  Future<void> updateGalleryOrder(List<GalleryDownloadInfo> gallerys) async {
    await appDb.transaction(() async {
      for (GalleryDownloadInfo gallery in gallerys) {
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(gallery.gid), sortOrder: Value(gallery.sortOrder)),
        );
      }
    });

    _invalidateGallerysCache();

    for (GalleryDownloadInfo gallery in gallerys) {
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
    GalleryDownloadInfo? gallery = gallerys.firstWhereOrNull((g) => g.gid == gid);
    if (gallery == null) {
      return false;
    }

    GalleryDownloadInfo? oldGallery = gallerys.firstWhereOrNull((g) => g.oldVersionGalleryUrl == gallery.galleryUrl);
    if (oldGallery == null) {
      return false;
    }

    return oldGallery.downloadProgress.downloadStatus != DownloadStatus.downloaded;
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
      final restored = _metadataStore.readForRestore(io.Directory(galleryDir.path));
      if (restored == null) {
        continue;
      }

      GalleryDownloadedData gallery = restored.gallery;
      List<GalleryImage?> images = restored.images;

      /// skip if exists
      if (galleryDownloadInfos.containsKey(gallery.gid)) {
        continue;
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

      _initGalleryInfoInMemoryWithIndices(gallery, restoredIndices);

      restoredCount++;
    }

    return restoredCount;
  }

  Future<void> updateImagePathAfterDownloadPathChanged() async {
    await appDb.transaction(() async {
      for (GalleryDownloadInfo gallery in gallerys) {
        await gallery.ensureImageIndicesLoaded();

        for (int serialNo = 0; serialNo < gallery.imageIndices.length; serialNo++) {
          GalleryImageIndex? idx = gallery.indexAt(serialNo);
          if (idx == null) {
            continue;
          }

          String newPath = DownloadPathResolver.computeImageDownloadRelativePath(gallery.toGalleryDownloadedData(), idx.url, serialNo);

          if (!await _updateImageInDatabase(
            ImageCompanion(gid: Value(gallery.gid), serialNo: Value(serialNo), path: Value(newPath)),
          )) {
            log.error('Update image path after download path changed failed');
          }
          gallery.updateImagePath(serialNo, newPath);

          update(['$downloadImageId::${gallery.gid}::$serialNo', '$downloadImageUrlId::${gallery.gid}::$serialNo']);
        }
      }
    });
  }

  Future<void> _generateComicInfoInDisk(GalleryDownloadInfo gallery) async {
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
      io.File file = io.File(path.join(DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery.toGalleryDownloadedData()), 'ComicInfo.xml'));
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
    for (GalleryDownloadInfo g in gallerys) {
      if (g.downloadProgress.downloadStatus == DownloadStatus.downloading) {
        // gid2SpeedComputer[g.gid]!.start();
        _resumeDownloadGallery(g.gid);
      }
    }
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
  void _submitImageTask(GalleryDownloadInfo gallery, int serialNo, AsyncTask<void> Function() taskBuilder) {
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
  int _computeGalleryTaskPriority(GalleryDownloadInfo gallery) {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return 0;
    }

    int groupPriority = galleryDownloadInfos[gallery.gid]!.priority * _priorityBase;

    if (downloadSetting.downloadAllGallerysOfSamePriority.isTrue) {
      return groupPriority;
    }

    /// priority is same, order by insert time — uses the cached
    /// [GalleryDownloadInfo.insertTimePriority] to avoid DateFormat.parse
    /// on every image task submit.
    int timePriority = galleryDownloadInfos[gallery.gid]!.insertTimePriority * 2000;

    return groupPriority + timePriority;
  }

  int _computeImageTaskPriority(GalleryDownloadInfo gallery, int serialNo) {
    return _computeGalleryTaskPriority(gallery) + serialNo;
  }

  /// Pause one gallery or all galleries depending on [pauseAll].
  /// Centralizes the pause/pauseAll branch repeated across parse/download handlers.
  Future<void> _pauseOnSiteError({required GalleryDownloadInfo gallery, required bool pauseAll, String? message}) {
    if (message != null) {
      snack('error'.tr, message, isShort: true);
    }
    return pauseAll ? pauseAllDownloadGallery() : pauseDownloadGallery(gallery);
  }

  bool _taskHasBeenPausedOrRemoved(GalleryDownloadInfo gallery) {
    return galleryDownloadInfos[gallery.gid] == null || galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus == DownloadStatus.paused;
  }

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  bool taskHasBeenPausedOrRemoved(GalleryDownloadInfo gallery) => _taskHasBeenPausedOrRemoved(gallery);

  bool _taskHasBeenRemoved(GalleryDownloadInfo gallery) {
    return galleryDownloadInfos[gallery.gid] == null;
  }

  /// Public alias for cross-class use (e.g. [GalleryDownloadTaskRunner]).
  bool taskHasBeenRemoved(GalleryDownloadInfo gallery) => _taskHasBeenRemoved(gallery);

  void submitImageTask(GalleryDownloadInfo gallery, int serialNo, AsyncTask<void> Function() taskBuilder) =>
      _submitImageTask(gallery, serialNo, taskBuilder);

  Future<void> pauseOnSiteError({required GalleryDownloadInfo gallery, required bool pauseAll, String? message}) =>
      _pauseOnSiteError(gallery: gallery, pauseAll: pauseAll, message: message);

  Future<void> tryCopyImageInfosFromImageHashes(GalleryDownloadInfo newGallery, List<String> imageHashes) =>
      _upgradeMigrator.copyImageInfosFromImageHashes(newGallery, imageHashes);

  Future<void> tryCopyImageInfoFromHref(String oldVersionGalleryUrl, GalleryDownloadInfo newGallery, int newImageSerialNo) =>
      _upgradeMigrator.tryCopyImageInfoFromHref(oldVersionGalleryUrl, newGallery, newImageSerialNo);

  Future<void> tryCopyImageInfoFromImage(String oldVersionGalleryUrl, GalleryDownloadInfo newGallery, int newImageSerialNo) =>
      _upgradeMigrator.tryCopyImageInfoFromImage(oldVersionGalleryUrl, newGallery, newImageSerialNo);

  Future<void> _updateProgressAfterImageDownloaded(GalleryDownloadInfo gallery, int serialNo) async {
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
  Future<void> updateProgressAfterImageDownloaded(GalleryDownloadInfo gallery, int serialNo) => _updateProgressAfterImageDownloaded(gallery, serialNo);

  Future<void> _instantiateFromDB() async {
    /// Parallelize the three startup DB queries — they have no data dependency
    /// on each other. Sequential awaits added ~3 round-trips to cold start.
    final results = await Future.wait([
      GalleryGroupDao.selectGalleryGroups(),
      GalleryDao.selectGallerys(),
      GalleryImageDao.selectCoverIndices(),
      GalleryImageDao.selectDownloadedCountsByGid(),
    ]);
    allGroups = (results[0] as List<GalleryGroupData>).map((e) => e.groupName).toList();
    log.debug('init Gallery groups: $allGroups');

    /// Get download info from database
    List<GalleryDownloadedData> dbGallerys = results[1] as List<GalleryDownloadedData>;

    /// Only load cover indices (serialNo=0) at startup — full image indices
    /// lazy-load on first access to each gallery (detail/read/download).
    Map<int, GalleryImageIndex> coverIndices = results[2] as Map<int, GalleryImageIndex>;
    Map<int, int> downloadedCounts = results[3] as Map<int, int>;

    for (GalleryDownloadedData gallery in dbGallerys) {
      /// Instantiate [Gallery] with an empty index list; we'll fill slot 0 below.
      _initGalleryInfoInMemory(gallery);

      GalleryDownloadInfo info = galleryDownloadInfos[gallery.gid]!;

      /// Populate cover index (slot 0) if a DB row exists.
      GalleryImageIndex? cover = coverIndices[gallery.gid];
      if (cover != null) {
        info.imageIndices[0] = cover;
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
  }

  Future<GalleryDownloadedData?> _initGalleryInfo(GalleryDownloadedData gallery) async {
    /// Compute and attach the sanitized title before the first DB write so the
    /// path is frozen for the lifetime of this download task.
    final int reservedBytes = utf8.encode('${gallery.gid} - ').length;
    gallery = gallery.copyWith(sanitizedTitle: Value(DownloadPathResolver.computeSanitizedGalleryTitle(gallery.title, reservedBytes)));

    if (!await _saveGalleryInfoAndGroupInDB(gallery)) {
      return null;
    }

    _initGalleryInfoInMemory(gallery);

    _saveGalleryMetadataInDisk(galleryDownloadInfos[gallery.gid]!);

    return gallery;
  }

  Future<void> _updateGalleryDownloadStatus(GalleryDownloadInfo gallery, DownloadStatus downloadStatus) async {
    await _updateGalleryInDatabase(
      GalleryDownloadedCompanion(gid: Value(gallery.gid), downloadStatusIndex: Value(downloadStatus.index)),
    );

    galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus = downloadStatus;

    _saveGalleryMetadataInDisk(gallery);
  }

  Future<bool> _updateImageStatus(GalleryDownloadInfo gallery, GalleryImage image, int serialNo, DownloadStatus downloadStatus) async {
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
  Future<bool> updateImageStatus(GalleryDownloadInfo gallery, GalleryImage image, int serialNo, DownloadStatus downloadStatus) =>
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

  /// Initialize in-memory state for a gallery that has **no image indices
  /// available yet** — e.g. just downloaded fresh, or loaded from DB at
  /// startup where indices lazy-load on first access. The
  /// [GalleryDownloadInfo.imageIndices] list starts all-null; curCount and
  /// hasDownloaded default to zero / all-false.
  void _initGalleryInfoInMemory(GalleryDownloadedData gallery) {
    _buildGalleryInfoInMemory(gallery, imageIndices: null);
  }

  /// Initialize in-memory state for a gallery with **already-known image
  /// indices** — e.g. restored from disk metadata, or imported from a
  /// folder of existing image files. curCount and hasDownloaded are derived
  /// from the indices.
  void _initGalleryInfoInMemoryWithIndices(
    GalleryDownloadedData gallery,
    List<GalleryImageIndex?> imageIndices,
  ) {
    _buildGalleryInfoInMemory(gallery, imageIndices: imageIndices);
  }

  void _buildGalleryInfoInMemory(
    GalleryDownloadedData gallery, {
    required List<GalleryImageIndex?>? imageIndices,
  }) {
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

    _invalidateGallerysCache();
    update([galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryInfoInMemory(GalleryDownloadInfo gallery) {
    _metadataStore.cancel(gallery.gid);
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadInfos.remove(gallery.gid);
    galleryDownloadInfo?._speedComputer?.dispose();

    _invalidateGallerysCache();
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
  Future<bool> saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) => _saveNewImageInfoInDatabase(image, serialNo, gid);

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

  void _saveGalleryMetadataInDisk(GalleryDownloadInfo gallery) => _metadataStore.save(gallery);

  /// Public alias for cross-class use (e.g. [GalleryUpgradeMigrator]).
  void saveGalleryMetadataInDisk(GalleryDownloadInfo gallery) => _metadataStore.save(gallery);

  Future<void> _flushMetadataSave(GalleryDownloadInfo gallery) => _metadataStore.flush(gallery);

  void _clearDownloadedImageInDisk(GalleryDownloadInfo gallery) {
    io.Directory directory = io.Directory(DownloadPathResolver.computeGalleryDownloadAbsolutePath(gallery.toGalleryDownloadedData()));
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

/// Business Object for initiating a gallery download or import. Carries only
/// the input fields a caller has at request time — runtime state (tasks,
/// cancelToken, downloadProgress) and DB-derived fields (sanitizedTitle,
/// sortOrder, insertTime, priority) are populated by the service.
///
/// This is the only shape external callers should use to start a download or
/// import; [GalleryDownloadedData] is an internal DB-layer detail.
class GalleryDownloadRequest {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String? uploader;
  final String publishTime;
  final bool downloadOriginalImage;
  final String group;
  final String tags;
  final String? tagRefreshTime;

  /// Set when this request is a gallery update from an older version.
  final String? oldVersionGalleryUrl;

  /// Optional overrides for service-owned fields. Null = service picks defaults
  /// (sortOrder=0, priority=[defaultDownloadGalleryPriority]). Used by
  /// [reDownloadGallery] to preserve user-assigned sort/priority across
  /// re-downloads.
  final int? sortOrder;
  final int? priority;

  const GalleryDownloadRequest({
    required this.gid,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    required this.publishTime,
    required this.downloadOriginalImage,
    required this.group,
    required this.tags,
    this.uploader,
    this.tagRefreshTime,
    this.oldVersionGalleryUrl,
    this.sortOrder,
    this.priority,
  });
}

class GalleryDownloadInfo implements Comparable<GalleryDownloadInfo> {
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

  /// Pre-parsed `MMddHHmmss` of [insertTime]. Cached at construction so
  /// [_computeGalleryTaskPriority] avoids `DateFormat.parse` on every image
  /// task submit.
  late final int _insertTimePriority = _parseInsertTimePriority();
  int get insertTimePriority => _insertTimePriority;

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

  GalleryDownloadSpeedComputer get speedComputer => _speedComputer ??= GalleryDownloadSpeedComputer(pageCount, _onSpeedUpdate);

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

  /// Build a [GalleryDownloadRequest] from this info's fields. Used when
  /// re-downloading or updating — the request is a pure-data snapshot that
  /// [downloadGallery] can consume to construct a fresh task.
  GalleryDownloadRequest toGalleryDownloadRequest() => GalleryDownloadRequest(
        gid: gid,
        token: token,
        title: title,
        category: category,
        pageCount: pageCount,
        galleryUrl: galleryUrl,
        uploader: uploader,
        publishTime: publishTime,
        downloadOriginalImage: downloadOriginalImage,
        group: group,
        tags: tags,
        tagRefreshTime: tagRefreshTime,
        oldVersionGalleryUrl: oldVersionGalleryUrl,
        sortOrder: sortOrder,
        priority: priority,
      );

  /// 'default' group always sorts last regardless of locale.
  static int groupSortRank(String group) => group == 'default'.tr ? 1 : 0;

  /// Canonical order: group rank → group name → sortOrder → insertTime desc.
  @override
  int compareTo(GalleryDownloadInfo other) {
    final rankCmp = groupSortRank(group) - groupSortRank(other.group);
    if (rankCmp != 0) {
      return rankCmp;
    }

    final groupCmp = group.compareTo(other.group);
    if (groupCmp != 0) {
      return groupCmp;
    }

    final orderCmp = sortOrder - other.sortOrder;
    if (orderCmp != 0) {
      return orderCmp;
    }

    return other.insertTime.compareTo(insertTime);
  }

  int _parseInsertTimePriority() {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(insertTime);
      return int.parse(DateFormat('MMddHHmmss').format(dt));
    } catch (_) {
      return 0;
    }
  }
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
