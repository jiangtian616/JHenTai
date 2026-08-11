import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;
import 'dart:isolate';

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
import 'package:jhentai/src/extension/list_extension.dart';
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
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/jh_response_parser.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart' as path;
import 'package:retry/retry.dart';

import '../../consts/locale_consts.dart';
import '../../database/dao/gallery_image_dao.dart';
import '../../exception/cancel_exception.dart';
import '../../exception/eh_site_exception.dart';
import '../../model/comic_info.dart';
import '../../model/detail_page_info.dart';
import '../../model/gallery_detail.dart';
import '../../model/gallery_image.dart';
import '../../network/eh_request.dart';
import '../../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../../utils/eh_executor.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/snack_util.dart';
import '../jh_service.dart';
import '../path_service.dart';
import 'download_path_resolver.dart';
import 'eh_image_exception_matcher.dart';

part 'gallery_download_task_runner.dart';
part 'gallery_upgrade_migrator.dart';
part 'gallery_metadata_store.dart';

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
  List<GalleryDownloadInfo>? _galleriesCache;

  /// Sorted view synthesized from [galleryDownloadInfos]. Single source of
  /// truth — the map holds the data; this getter returns a cached sorted
  /// snapshot, rebuilt only when the set or order-affecting fields change.
  List<GalleryDownloadInfo> get galleries {
    return _galleriesCache ??= _rebuildGalleriesCache();
  }

  List<GalleryDownloadInfo> _rebuildGalleriesCache() {
    final List<GalleryDownloadInfo> list = galleryDownloadInfos.values.toList();
    list.sort();
    return list;
  }

  /// Invalidate the sorted cache. Call after any mutation that could affect
  /// order or membership: add, delete, group change, group rename, priority
  /// change. (sortOrder/insertTime are immutable post-creation.)
  void _invalidateGalleriesCache() {
    _galleriesCache = null;
  }

  /// Filter galleries by group from the cached sorted [galleries] list —
  /// result preserves the canonical sort order. O(N) walk of the cache,
  /// no extra sort.
  List<GalleryDownloadInfo> galleriesWithGroup(String group) {
    return galleries.where((g) => g.group == group).toList();
  }

  static const int _maxRetryTimes = 3;
  static const int defaultDownloadGalleryPriority = 4;

  /// Backward-compat alias — external callers read this const to locate the
  /// metadata file. The canonical home is now [_GalleryMetadataStore].
  static const String metadataFileName = _GalleryMetadataStore.metadataFileName;
  static const int _priorityBase = 100000000;

  final Completer<bool> _completer = Completer();

  Future<bool> get completed => _completer.future;

  Worker? _downloadSettingListener;

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);

    await _instantiateFromDB();

    log.debug('Gallery download task count: ${galleries.length}');

    _startExecutor();

    _completer.complete(true);

    _downloadSettingListener = everAll(
      [downloadSetting.downloadTaskConcurrency, downloadSetting.maximum, downloadSetting.period],
      (_) {
        updateExecutor();
      },
    );

    if (downloadSetting.restoreTasksAutomatically.isTrue) {
      restoreTasks();
    }
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

    if (!await _initGalleryInfo(gallery)) {
      return;
    }

    _generateComicInfoInDisk(galleryDownloadInfos[gallery.gid]!);

    await _startDownloadTask(galleryDownloadInfos[gallery.gid]!);

    log.info('Begin to download gallery: ${gallery.title}, original: ${gallery.downloadOriginalImage}');
  }

  Future<void> _startDownloadTask(GalleryDownloadInfo info) async {
    info.speedComputer.start();

    /// Pre-load full images so synchronous reads during download (e.g.
    /// `_downloadImageTask` reading `image.url`) work without per-call awaits.
    await info.ensureImagesLoaded();

    _submitTask(
      gid: info.gid,
      priority: _computeGalleryTaskPriority(info),
      task: _GalleryDownloadTaskRunner(this, info).downloadGalleryTask(),
    );
  }

  /// Convert a [GalleryDownloadRequest] BO to the DB-row shape for internal
  /// persistence. Status, sortOrder, insertTime, and priority are service-
  /// owned — callers cannot set them.
  GalleryDownloadedData _toGalleryDownloadedData(GalleryDownloadRequest request, DownloadStatus status) {
    /// Compute sanitizedTitle up-front so the row is born with the path that
    /// will be frozen for the lifetime of this download task.
    final int reservedBytes = utf8.encode('${request.gid} - ').length;
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
      sanitizedTitle: DownloadPathResolver.computeSanitizedGalleryTitle(request.title, reservedBytes),
    );
  }

  Future<void> pauseAllDownloadGallery() async {
    /// Snapshot the downloading galleries — pauseDownloadGallery mutates
    /// `downloadProgress.downloadStatus` mid-iteration, so we can't filter
    /// lazily against the live map.
    final List<GalleryDownloadInfo> downloading = galleryDownloadInfos.values.where((g) => g.downloadProgress.downloadStatus == DownloadStatus.downloading).toList();
    if (downloading.isEmpty) {
      return;
    }

    /// Single transaction: bulk gallery status + bulk image status.
    /// Avoids N per-gallery DB round-trips (one UPDATE + one image-batch
    /// UPDATE per gallery × thousands of galleries).
    ///
    /// CAS guard: pass `fromStatusIndex: downloading` so a gallery already
    /// flipped to `downloaded` by a concurrent `_updateProgressAfterImageDownloaded`
    /// is NOT overwritten back to `paused` — its WHERE clause won't match.
    /// The image-side UPDATE carries the same condition implicitly via
    /// `WHERE downloadStatusIndex = downloading`. Memory-side re-check at
    /// line 262 (`_liveInfoOrSkip`) catches any concurrent winner.
    await appDb.transaction(() async {
      await GalleryDao.batchUpdateGallery(
        downloading
            .map((g) => GalleryDownloadedCompanion(
                  gid: Value(g.gid),
                  downloadStatusIndex: Value(DownloadStatus.paused.index),
                ))
            .toList(),
        fromStatusIndex: DownloadStatus.downloading.index,
      );
      await GalleryImageDao.updateImageStatusByGids(
        downloading.map((g) => g.gid),
        DownloadStatus.downloading.index,
        DownloadStatus.paused.index,
      );
    });

    /// In-memory + UI updates per gallery. No further DB writes here.
    for (final gallery in downloading) {
      /// Re-check status after the transaction's await. A concurrent path
      /// (deleteGallery → _clearGalleryInfoInMemory, or a download completing
      /// → _updateProgressAfterImageDownloaded flipping status to downloaded)
      /// may have already mutated or removed this entry. Skip the in-memory
      /// mutation if so — the winning path's state should be honored, and
      /// the DB writes from the transaction above remain authoritative.
      final GalleryDownloadInfo? info = _liveInfoOrSkip(gallery.gid, DownloadStatus.downloading);
      if (info == null) {
        continue;
      }
      info.downloadProgress.downloadStatus = DownloadStatus.paused;

      for (AsyncTask task in info.tasks) {
        executor.cancelTask(task);
      }
      info.tasks.clear();
      info.cancelToken.cancel();
      info.speedComputer.pause();

      for (GalleryImage? img in info.images ?? <GalleryImage?>[]) {
        if (img?.downloadStatus == DownloadStatus.downloading) {
          img?.downloadStatus = DownloadStatus.paused;
          update(['$downloadImageId::${gallery.gid}']);
        }
      }

      await _flushMetadataSave(gallery);
      update(['$galleryDownloadProgressId::${gallery.gid}']);
    }
  }

  GalleryDownloadInfo? _findGalleryByGid(int gid) => galleryDownloadInfos[gid];

  /// Concurrency-safe lookup for use at await boundaries in multi-step
  /// operations (pauseAll / resumeAll / etc.). Returns the live info iff the
  /// gallery is still resident AND its `downloadStatus` still matches
  /// [expected]; otherwise null.
  ///
  /// A null return means a concurrent path (deleteGallery, completed
  /// download, _pauseOnSiteError, etc.) has mutated or removed the entry —
  /// the caller should bail out of its remaining in-memory mutations to
  /// avoid (a) null-bang crashes from `galleryDownloadInfos[gid]!` and
  /// (b) overwriting the winning path's state with stale values. DB writes
  /// that already landed in the transaction remain authoritative.
  GalleryDownloadInfo? _liveInfoOrSkip(int gid, DownloadStatus expected) {
    final GalleryDownloadInfo? info = galleryDownloadInfos[gid];
    if (info == null || info.downloadProgress.downloadStatus != expected) {
      return null;
    }
    return info;
  }

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

    for (GalleryImage? img in galleryDownloadInfo.images ?? <GalleryImage?>[]) {
      if (img?.downloadStatus == DownloadStatus.downloading) {
        img?.downloadStatus = DownloadStatus.paused;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    await _flushMetadataSave(gallery);

    log.info('Pause download gallery: ${gallery.title}');
  }

  Future<void> resumeAllDownloadGallery() async {
    final List<GalleryDownloadInfo> paused = galleryDownloadInfos.values.where((g) => g.downloadProgress.downloadStatus == DownloadStatus.paused).toList();
    if (paused.isEmpty) return;

    /// Single transaction: bulk gallery status + bulk image status.
    /// CAS guard: pass `fromStatusIndex: paused` so a gallery flipped away
    /// from `paused` by a concurrent path (e.g. deleteGallery) is skipped.
    await appDb.transaction(() async {
      await GalleryDao.batchUpdateGallery(
        paused
            .map((g) => GalleryDownloadedCompanion(
                  gid: Value(g.gid),
                  downloadStatusIndex: Value(DownloadStatus.downloading.index),
                ))
            .toList(),
        fromStatusIndex: DownloadStatus.paused.index,
      );
      await GalleryImageDao.updateImageStatusByGids(
        paused.map((g) => g.gid),
        DownloadStatus.paused.index,
        DownloadStatus.downloading.index,
      );
    });

    for (final gallery in paused) {
      final GalleryDownloadInfo? info = _liveInfoOrSkip(gallery.gid, DownloadStatus.paused);
      if (info == null) {
        continue;
      }
      info.downloadProgress.downloadStatus = DownloadStatus.downloading;

      /// can't reuse cancelToken across pause/resume
      info.cancelToken = CancelToken();
      info.speedComputer.start();

      for (GalleryImage? img in info.images ?? <GalleryImage?>[]) {
        if (img?.downloadStatus == DownloadStatus.paused) {
          img?.downloadStatus = DownloadStatus.downloading;
          update(['$downloadImageId::${gallery.gid}']);
        }
      }

      _saveGalleryMetadataInDisk(gallery);
      update(['$galleryDownloadProgressId::${gallery.gid}']);

      /// Re-submit the gallery task — single-launch, no per-image await needed.
      _submitTask(
        gid: info.gid,
        priority: _computeGalleryTaskPriority(info),
        task: _GalleryDownloadTaskRunner(this, info).downloadGalleryTask(),
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

    for (GalleryImage? img in galleryDownloadInfo.images ?? <GalleryImage?>[]) {
      if (img?.downloadStatus == DownloadStatus.paused) {
        img?.downloadStatus = DownloadStatus.downloading;
        update(['$downloadImageId::${gallery.gid}']);
      }
    }

    log.info('Resume download gallery: ${gallery.title}');

    _saveGalleryMetadataInDisk(gallery);

    _resumeDownloadGallery(gallery.gid);
  }

  /// Resume a paused download. The [GalleryDownloadInfo] must already exist.
  Future<void> _resumeDownloadGallery(int gid) async {
    await _startDownloadTask(galleryDownloadInfos[gid]!);
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
    if (gallery == null) {
      return;
    }

    await gallery.ensureImagesLoaded();
    final GalleryImage? image = gallery.imageAtSync(serialNo);
    if (image == null) {
      return;
    }

    log.info('Re-download image, gid: $gid, index: $serialNo');

    /// Snapshot the per-image downloaded flag and materialize the list BEFORE
    /// the status flip below. [GalleryDownloadProgress.hasDownloaded]
    /// synthesizes an all-true list for `downloaded` galleries (backing
    /// `_hasDownloaded` stays null); reading it after the CAS to `downloading`
    /// would lazily allocate an all-false list — this decrement would never
    /// fire, curCount would overshoot pageCount, and the gallery would stall
    /// in `downloading` (the `curCount == totalCount` completion check would
    /// never match again).
    final bool wasDownloaded = gallery.downloadProgress.hasDownloaded[serialNo];

    /// Copy the synthesized list into `_hasDownloaded` while still in the old
    /// status, so flipping this one image back to downloading below doesn't
    /// reset every other downloaded image's flag to false.
    gallery.downloadProgress.hasDownloaded = List<bool>.from(gallery.downloadProgress.hasDownloaded);

    /// If the gallery is not currently `downloading`, CAS-flip it to
    /// `downloading` first (gated on the current status). This covers both
    /// `downloaded` (re-download a completed gallery's image) and `paused`
    /// (re-download while paused — implicit resume). CAS-first ensures that
    /// if a concurrent path (deleteGallery, pauseAll, resumeAll) beat us to
    /// the status flip, we bail BEFORE touching memory, image rows, or disk
    /// files. A gallery already in `downloading` needs no flip — its task
    /// pipeline is in flight and will (re)process this image.
    final DownloadStatus currentStatus = gallery.downloadProgress.downloadStatus;
    if (currentStatus != DownloadStatus.downloading) {
      final bool flipped = await _updateGalleryDownloadStatus(
        gallery,
        DownloadStatus.downloading,
        fromStatus: currentStatus,
      );
      if (!flipped) {
        log.download('reDownloadImage: CAS failed (gid=$gid, expected=$currentStatus→downloading); concurrent path won, bailing.');
        return;
      }
    }

    await _updateImageStatus(gallery, image, serialNo, DownloadStatus.downloading);

    _deleteImageInDisk(image);

    if (wasDownloaded) {
      gallery.downloadProgress.curCount--;
    }
    gallery.downloadProgress.hasDownloaded[serialNo] = false;
    gallery.speedComputer.resetProgress(serialNo);
    gallery.speedComputer.start();

    update(['$galleryDownloadSuccessId::${gallery.gid}', '$galleryDownloadProgressId::${gallery.gid}']);

    _GalleryDownloadTaskRunner(this, gallery)._reParseImageUrlAndDownload(serialNo);
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
    _invalidateGalleriesCache();

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
    _invalidateGalleriesCache();
    _saveGalleryMetadataInDisk(gallery);

    return true;
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    List<GalleryDownloadInfo> galleriesInGroup = galleriesWithGroup(oldGroup);

    await appDb.transaction(() async {
      if (!allGroups.contains(newGroup) && !await _addGroup(newGroup)) {
        return;
      }

      for (GalleryDownloadInfo g in galleriesInGroup) {
        g.group = newGroup;
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(g.gid), groupName: Value(newGroup)),
        );
      }

      await _deleteGroup(oldGroup);
    });

    /// Mark dirty after the transaction commits — `_saveGalleryMetadataInDisk`
    /// schedules a throttled disk write via timer, which must not be armed
    /// inside a DB transaction (the write would race with rollback).
    for (GalleryDownloadInfo g in galleriesInGroup) {
      _saveGalleryMetadataInDisk(g);
    }

    _invalidateGalleriesCache();
  }

  Future<void> deleteGroup(String group) {
    return _deleteGroup(group);
  }

  Future<void> updateGalleryOrder(List<GalleryDownloadInfo> galleries) async {
    await appDb.transaction(() async {
      for (GalleryDownloadInfo gallery in galleries) {
        await _updateGalleryInDatabase(
          GalleryDownloadedCompanion(gid: Value(gallery.gid), sortOrder: Value(gallery.sortOrder)),
        );
      }
    });

    _invalidateGalleriesCache();

    for (GalleryDownloadInfo gallery in galleries) {
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
    GalleryDownloadInfo? gallery = galleries.firstWhereOrNull((g) => g.gid == gid);
    if (gallery == null) {
      return false;
    }

    GalleryDownloadInfo? oldGallery = galleries.firstWhereOrNull((g) => g.oldVersionGalleryUrl == gallery.galleryUrl);
    if (oldGallery == null) {
      return false;
    }

    return oldGallery.downloadProgress.downloadStatus != DownloadStatus.downloaded;
  }

  /// Use metadata in each gallery folder to restore download status, then sync to database.
  /// This is used after re-install app, or share download folder to another user.
  ///
  /// Metadata parsing runs in a background isolate to avoid UI jank when
  /// hundreds of galleries each parse a multi-KB JSON file. DB writes stay on
  /// the main isolate (Drift's connection isn't isolate-safe).
  ///
  /// Concurrent calls are coalesced — if a restore is already in flight, the
  /// caller awaits the same future instead of starting a second pass (which
  /// would race on DB inserts and double-count galleries).
  Future<int>? _restoreTasksFuture;

  Future<int> restoreTasks() async {
    await completed;

    /// Coalesce concurrent triggers (e.g. user taps "restore" while the
    /// auto-restore on startup is still running). The second caller awaits
    /// the first's result.
    if (_restoreTasksFuture != null) {
      return _restoreTasksFuture!;
    }
    _restoreTasksFuture = _doRestoreTasks();
    try {
      return await _restoreTasksFuture!;
    } finally {
      _restoreTasksFuture = null;
    }
  }

  Future<int> _doRestoreTasks() async {
    io.Directory downloadDir = io.Directory(downloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    final List<String> galleryDirPaths = downloadDir.listSync().whereType<io.Directory>().map((d) => d.path).toList();
    if (galleryDirPaths.isEmpty) {
      return 0;
    }

    /// Parse all metadata files in a single background isolate. Each parse
    /// is pure (static [_GalleryMetadataStore.readForRestore]); only primitive
    /// paths cross the isolate boundary.
    final List<({GalleryDownloadedData gallery, List<GalleryImage?> images})?> restoredList = await Isolate.run(() {
      return galleryDirPaths.map((p) {
        try {
          return _GalleryMetadataStore.readForRestore(io.Directory(p));
        } catch (e, st) {
          // Logging from a worker isolate may not reach file handlers; swallow
          // here so one bad metadata file doesn't abort the whole restore.
          return null;
        }
      }).toList();
    });

    int restoredCount = 0;
    for (final ({GalleryDownloadedData gallery, List<GalleryImage?> images})? restored in restoredList) {
      if (restored == null) {
        continue;
      }

      GalleryDownloadedData gallery = restored.gallery;
      List<GalleryImage?> images = restored.images;

      /// A gallery left in `downloading` state at shutdown cannot be safely
      /// resumed — its image tasks were killed mid-flight. Demote to `paused`
      /// so the user explicitly resumes, rather than silently re-launching
      /// downloads that may have half-written image files.
      if (gallery.downloadStatusIndex == DownloadStatus.downloading.index) {
        gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
      }

      /// skip if exists
      if (galleryDownloadInfos.containsKey(gallery.gid)) {
        continue;
      }

      if (!await _restoreInfoInDatabase(gallery, images)) {
        log.error('Restore download failed. Gallery: ${gallery.title}');
        _clearGalleryDownloadInfoInDatabase(gallery.gid);
        continue;
      }

      /// Restore images directly into the in-memory [GalleryDownloadInfo.images]
      /// list. The restored list is sized to pageCount; missing slots stay null.
      List<GalleryImage?> restoredImages = List.generate(gallery.pageCount, (_) => null);
      for (int serialNo = 0; serialNo < images.length && serialNo < gallery.pageCount; serialNo++) {
        final GalleryImage? img = images[serialNo];
        if (img != null) {
          restoredImages[serialNo] = img;
        }
      }

      _initGalleryInfoInMemoryWithImages(gallery, restoredImages);

      /// The metadata-restore path loads every gallery's full image list
      /// (to derive curCount/hasDownloaded and the metadata snapshot). No
      /// consumer retains at startup, so evict completed galleries' lists
      /// right away to match the DB path ([_instantiateFromDB] loads only
      /// coverImage). [GalleryDownloadInfo.evictImages] keeps coverImage
      /// (serialNo 0) resident for list/grid cover display; incomplete
      /// galleries keep their list for the download loop.
      if (gallery.downloadStatusIndex == DownloadStatus.downloaded.index) {
        galleryDownloadInfos[gallery.gid]!.evictImages();
      }

      restoredCount++;
    }

    return restoredCount;
  }

  /// Re-compute every image's on-disk path after the user changes the download
  /// root directory. Processes galleries in batches of [_pathUpdateBatchSize]
  /// inside separate transactions: each batch loads images into memory, updates
  /// DB rows + in-memory paths, then evicts completed galleries to bound peak
  /// memory. Avoids holding all galleries' images resident simultaneously.
  static const int _pathUpdateBatchSize = 200;

  Future<void> updateImagePathAfterDownloadPathChanged() async {
    final List<GalleryDownloadInfo> allGalleries = galleries.toList();

    for (int i = 0; i < allGalleries.length; i += _pathUpdateBatchSize) {
      final List<GalleryDownloadInfo> batch = allGalleries.skip(i).take(_pathUpdateBatchSize).toList();

      await appDb.transaction(() async {
        for (final GalleryDownloadInfo info in batch) {
          await info.ensureImagesLoaded();

          for (int serialNo = 0; serialNo < info.pageCount; serialNo++) {
            final GalleryImage? img = info.imageAtSync(serialNo);
            if (img == null) {
              continue;
            }

            final String newPath = DownloadPathResolver.computeImageDownloadRelativePath(
              info.toGalleryDownloadedData(),
              _downloadUrlFor(info.toGalleryDownloadedData(), img),
              serialNo,
            );

            if (img.path == newPath) {
              continue;
            }

            if (!await _updateImageInDatabase(
              ImageCompanion(gid: Value(info.gid), serialNo: Value(serialNo), path: Value(newPath)),
            )) {
              log.error('Update image path after download path changed failed');
            }
            info.updateImagePath(serialNo, newPath);

            update(['$downloadImageId::${info.gid}::$serialNo', '$downloadImageUrlId::${info.gid}::$serialNo']);
          }
        }
      });

      /// Evict completed galleries after each batch to release memory. In-
      /// complete galleries keep their images resident for the download loop.
      for (final GalleryDownloadInfo info in batch) {
        if (info.downloadProgress.downloadStatus == DownloadStatus.downloaded) {
          info.evictImages();
        }
      }
    }
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
      log.error('Generate comic info failed due to network error, gallery: ${gallery.gid}', e);
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
    for (GalleryDownloadInfo g in galleries) {
      if (g.downloadProgress.downloadStatus == DownloadStatus.downloading) {
        // gid2SpeedComputer[g.gid]!.start();
        _resumeDownloadGallery(g.gid);
      }
    }
  }

  void _submitTask({required int gid, required int priority, required AsyncTask<void> task}) {
    galleryDownloadInfos[gid]?.tasks.add(task);

    executor.scheduleTask(priority, task).then((_) => galleryDownloadInfos[gid]?.tasks.remove(task)).onError((e, stackTrace) {
      galleryDownloadInfos[gid]?.tasks.remove(task);
      if (e is! CancelException) {
        log.error('Executor exception!', e, stackTrace);
        log.uploadError(e);
      }
      return null;
    });
  }

  /// Shortcut for the common pattern: compute image priority, build the task, submit.
  ///
  /// Status-gated: refuses to submit a new task if the gallery's downloadStatus
  /// is no longer [DownloadStatus.downloading] (paused / completed / deleted).
  /// Without this gate, a task could be added to [info.tasks] between
  /// pauseAll's `info.tasks.clear()` and the next iteration, becoming an
  /// orphan tracked by the executor but not by [info.tasks] — un-cancelable.
  void _submitImageTask(GalleryDownloadInfo gallery, int serialNo, AsyncTask<void> Function() taskBuilder) {
    final GalleryDownloadInfo? info = _liveInfoOrSkip(gallery.gid, DownloadStatus.downloading);
    if (info == null) {
      return;
    }
    return _submitTask(
      gid: gallery.gid,
      priority: _computeImageTaskPriority(gallery, serialNo),
      task: taskBuilder(),
    );
  }

  /// Rules:
  /// 1. If [downloadAllGalleriesOfSamePriority] is false
  ///   1.1 Galleries download order:
  ///     1.1.1 gallery with high priority
  ///     1.1.2 gallery with low priority
  ///     1.1.3 if priority is same, download only 1 gallery simultaneously in the order of insert time ASC
  ///   1.2 For each gallery, previous image should be downloaded earlier
  /// 2. If [downloadAllGalleriesOfSamePriority] is true
  ///   2.1 Galleries download order:
  ///     2.1.1 gallery with high priority
  ///     2.1.2 gallery with low priority
  ///     2.1.3 if priority is same, download all galleries simultaneously
  ///   2.2 For each gallery, previous image should be downloaded earlier and images with same [serialNo] has the same priority no matter which gallery they belong to
  ///
  /// Because a gallery has most 2000 images, we assign 2000 numbers to each gallery
  int _computeGalleryTaskPriority(GalleryDownloadInfo gallery) {
    if (_taskHasBeenPausedOrRemoved(gallery)) {
      return 0;
    }

    int groupPriority = galleryDownloadInfos[gallery.gid]!.priority * _priorityBase;

    if (downloadSetting.downloadAllGalleriesOfSamePriority.isTrue) {
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

  bool _taskHasBeenRemoved(GalleryDownloadInfo gallery) {
    return galleryDownloadInfos[gallery.gid] == null;
  }

  Future<void> _updateProgressAfterImageDownloaded(GalleryDownloadInfo gallery, int serialNo) async {
    /// Status-gate at entry: if a concurrent pause / pauseAll / delete has
    /// flipped status away from [DownloadStatus.downloading], this is a late
    /// completion racing with the pause path — bail out without mutating
    /// curCount / hasDownloaded / status / evicting images. The pause path
    /// is authoritative for paused state; a late increment here would either
    /// (a) overshoot curCount past the actual downloaded count, or (b) flip
    /// status back to `downloaded` after pauseAll just set it to `paused`,
    /// leaving DB (`paused`) and memory (`downloaded`) diverged.
    final GalleryDownloadInfo? info = _liveInfoOrSkip(gallery.gid, DownloadStatus.downloading);
    if (info == null) {
      return;
    }

    GalleryDownloadProgress downloadProgress = info.downloadProgress;
    downloadProgress.curCount++;
    downloadProgress.hasDownloaded[serialNo] = true;

    if (downloadProgress.curCount == downloadProgress.totalCount) {
      /// Don't pre-flip memory status before the await — the CAS may fail if
      /// a concurrent pauseAll beat us to it, in which case DB stays `paused`
      /// and we must NOT set memory to `downloaded` (would diverge). The
      /// `_updateGalleryDownloadStatus` call writes memory only on CAS success.
      final bool flipped = await _updateGalleryDownloadStatus(
        gallery,
        DownloadStatus.downloaded,
        fromStatus: DownloadStatus.downloading,
      );

      /// Re-check after the await: CAS failure means a concurrent pauseAll
      /// flipped status to `paused` (memory not written to `downloaded`);
      /// or deleteGallery may have removed the entry. Either way, bail
      /// without disposing speedComputer or evicting images — the gallery
      /// is not in the `downloaded` state we expected.
      if (!flipped) {
        log.download('Completion CAS failed: gid=${gallery.gid}, expected=downloading→downloaded; a concurrent path (likely pauseAll) changed status. Skipping evict/dispose.');
        return;
      }
      final GalleryDownloadInfo? live = _liveInfoOrSkip(gallery.gid, DownloadStatus.downloaded);
      if (live == null) {
        return;
      }
      live.speedComputer.dispose();

      /// All images downloaded — evict the full image list. Cover image is
      /// retained for list/grid cover display; full list re-loads on next
      /// read page / detail page open.
      live.evictImages();
      update(['$galleryDownloadSuccessId::${gallery.gid}']);
    }

    update(['$galleryDownloadProgressId::${gallery.gid}']);
  }

  Future<void> _instantiateFromDB() async {
    /// Parallelize the three startup DB queries — they have no data dependency
    /// on each other. Sequential awaits added ~3 round-trips to cold start.
    final List<Object> results = await Future.wait([
      GalleryGroupDao.selectGalleryGroups(),
      GalleryDao.selectGalleries(),
      GalleryImageDao.selectCoverImages(),
      GalleryImageDao.selectDownloadedCountsByGid(),
    ]);
    allGroups = (results[0] as List<GalleryGroupData>).map((e) => e.groupName).toList();
    log.debug('init Gallery groups: $allGroups');

    /// Get download info from database
    List<GalleryDownloadedData> dbGalleries = results[1] as List<GalleryDownloadedData>;

    /// Only load cover images (serialNo=0) at startup — full image lists
    /// lazy-load on first access to each gallery (detail/read/download).
    Map<int, GalleryImage> covers = results[2] as Map<int, GalleryImage>;
    Map<int, int> downloadedCounts = results[3] as Map<int, int>;

    for (GalleryDownloadedData gallery in dbGalleries) {
      _initGalleryInfoInMemory(gallery);

      GalleryDownloadInfo info = galleryDownloadInfos[gallery.gid]!;

      /// Populate cover image (slot 0) if a DB row exists.
      info.coverImage = covers[gallery.gid];

      /// Populate curCount: for fully-downloaded galleries, it equals pageCount;
      /// otherwise use the precise count from DB. hasDownloaded defers to the
      /// getter for completed galleries and syncs from [images] on first
      /// load for incomplete ones.
      int downloadedCount = downloadedCounts[gallery.gid] ?? 0;
      if (info.downloadProgress.downloadStatus == DownloadStatus.downloaded) {
        info.downloadProgress.curCount = gallery.pageCount;
      } else {
        info.downloadProgress.curCount = downloadedCount;
      }
    }
  }

  Future<bool> _initGalleryInfo(GalleryDownloadedData gallery) async {
    if (!await _saveGalleryInfoAndGroupInDB(gallery)) {
      return false;
    }

    _initGalleryInfoInMemory(gallery);

    _saveGalleryMetadataInDisk(galleryDownloadInfos[gallery.gid]!);

    return true;
  }

  Future<bool> _updateGalleryDownloadStatus(
    GalleryDownloadInfo gallery,
    DownloadStatus downloadStatus, {
    DownloadStatus? fromStatus,
  }) async {
    /// CAS: when [fromStatus] is provided, the DB UPDATE is gated on the
    /// current row's `downloadStatusIndex` matching it. This prevents lost
    /// updates when a concurrent `pauseAllDownloadGallery` / `resumeAllDownloadGallery`
    /// has already flipped the row. Without this, a late completion writing
    /// `downloaded` could overwrite a just-written `paused`, or vice versa.
    ///
    /// Memory mutation follows the DB result: if 0 rows updated, the CAS
    /// failed (someone else won) — skip the memory write so memory stays
    /// consistent with DB.
    final GalleryDownloadedCompanion companion = GalleryDownloadedCompanion(
      gid: Value(gallery.gid),
      downloadStatusIndex: Value(downloadStatus.index),
    );
    final bool success = fromStatus == null
        ? await _updateGalleryInDatabase(companion)
        : await _updateGalleryInDatabase(companion, fromStatusIndex: fromStatus.index);

    if (!success) {
      log.download('CAS skip on _updateGalleryDownloadStatus: gid=${gallery.gid}, expected=$fromStatus, target=$downloadStatus');
      return false;
    }

    galleryDownloadInfos[gallery.gid]?.downloadProgress.downloadStatus = downloadStatus;

    _saveGalleryMetadataInDisk(gallery);
    return true;
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

  /// Initialize in-memory state for a gallery that has **no image data
  /// resident** — e.g. just downloaded fresh, or loaded from DB at startup
  /// where [images] lazy-loads on first access. [coverImage] is populated
  /// separately by the caller (e.g. from [GalleryImageDao.selectCoverImages]);
  /// curCount and hasDownloaded default to zero / all-false.
  void _initGalleryInfoInMemory(GalleryDownloadedData gallery) {
    _buildGalleryInfoInMemory(gallery, images: null);
  }

  /// Initialize in-memory state for a gallery with **already-known images**
  /// — e.g. restored from disk metadata, or imported from a folder of
  /// existing image files. curCount and hasDownloaded are derived from the
  /// images list.
  void _initGalleryInfoInMemoryWithImages(GalleryDownloadedData gallery, List<GalleryImage?> images) {
    _buildGalleryInfoInMemory(gallery, images: images);
  }

  void _buildGalleryInfoInMemory(GalleryDownloadedData gallery, {required List<GalleryImage?>? images}) {
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
        curCount: images?.fold<int>(0, (total, img) => total + (img?.downloadStatus == DownloadStatus.downloaded ? 1 : 0)) ?? 0,
        totalCount: gallery.pageCount,
        downloadStatus: DownloadStatus.values[gallery.downloadStatusIndex],
        hasDownloaded: images?.map((img) => img?.downloadStatus == DownloadStatus.downloaded).toList(),
      ),
      imageHrefs: List.generate(gallery.pageCount, (_) => null),
      images: images,
      onSpeedUpdate: () => update(['$galleryDownloadSpeedComputerId::${gallery.gid}']),
    );

    _invalidateGalleriesCache();
    update([galleryCountChangedId, '$galleryDownloadProgressId::${gallery.gid}']);
  }

  void _clearGalleryInfoInMemory(GalleryDownloadInfo gallery) {
    _metadataStore.cancel(gallery.gid);
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadInfos.remove(gallery.gid);
    galleryDownloadInfo?._speedComputer?.dispose();

    _invalidateGalleriesCache();
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
            originalImageUrl: image.originalImageUrl,
            path: image.path!,
            imageHash: image.imageHash ?? '',
            downloadStatusIndex: image.downloadStatus.index,
          ),
        ) >
        0;
  }

  Future<bool> _updateGalleryInDatabase(GalleryDownloadedCompanion gallery, {int? fromStatusIndex}) async {
    return await GalleryDao.updateGallery(gallery, fromStatusIndex: fromStatusIndex) > 0;
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

  /// Persist a restored gallery + its images to DB. Caller ([restoreTasks])
  /// is responsible for status fix-ups (e.g. demoting `downloading` →
  /// `paused`); this method only does DB writes.
  Future<bool> _restoreInfoInDatabase(GalleryDownloadedData gallery, List<GalleryImage?> images) async {
    if (!await _saveGalleryInfoAndGroupInDB(gallery)) {
      return false;
    }

    return await appDb.transaction(() async {
      final List<ImageData> imageRows = <ImageData>[];
      for (int serialNo = 0; serialNo < images.length && serialNo < gallery.pageCount; serialNo++) {
        final GalleryImage? image = images[serialNo];
        if (image == null) {
          continue;
        }
        imageRows.add(ImageData(
          gid: gallery.gid,
          serialNo: serialNo,
          url: image.url,
          originalImageUrl: image.originalImageUrl,
          path: image.path!,
          imageHash: image.imageHash ?? '',
          downloadStatusIndex: image.downloadStatus.index,
        ));
      }
      await GalleryImageDao.batchInsertImages(imageRows);
      return true;
    }).catchError((e) {
      log.error('Restore images into database error', e);
      log.uploadError(e);
      return false;
    });
  }

  // Disk

  /// Per-gallery metadata JSON persistence (debounced writes + disk reads for restore).
  late final _GalleryMetadataStore _metadataStore = _GalleryMetadataStore(this);

  /// Gallery upgrade migration: copy image bytes + metadata from an old gallery
  /// version to a new one by matching imageHash.
  late final _GalleryUpgradeMigrator _upgradeMigrator = _GalleryUpgradeMigrator(this);

  void _saveGalleryMetadataInDisk(GalleryDownloadInfo gallery) => _metadataStore.save(gallery);

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

/// Pick the URL to actually download from, given the gallery's
/// `downloadOriginalImage` flag. Used by the download pipeline (parse url,
/// download bytes, upgrade migration, path recompute) and by metadata restore.
///
/// For download-original galleries, prefer [GalleryImage.originalImageUrl] and
/// fall back to [GalleryImage.url] if the original URL is missing (legacy rows
/// written before the `originalImageUrl` column existed, where `url` itself
/// stores the original URL). For regular galleries, always use `url`.
///
/// Free function (not a method on [GalleryImage]) so it can be called from
/// any context — including the metadata store's [Isolate.run] restore path,
/// which only has a [GalleryDownloadedData] (parsed from JSON) and no access
/// to the [GalleryDownloadInfo] singleton.
String _downloadUrlFor(GalleryDownloadedData gallery, GalleryImage image) {
  return gallery.downloadOriginalImage ? (image.originalImageUrl ?? image.url) : image.url;
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

  /// Cover image (serialNo == 0), always resident. Loaded at startup from
  /// DB; used by list/grid/search pages. Other serialNos go through
  /// [ensureImagesLoaded] / [imageAtSync].
  GalleryImage? coverImage;

  /// Full image list, `null` when not resident in memory.
  /// - Startup: `null` (only [coverImage] loaded)
  /// - Download start: [ensureImagesLoaded] pulls from DB (or new empty list)
  /// - Download complete: [evictImages] → `null`
  /// - Read page open: [ensureImagesLoaded] pulls from DB
  /// - Read page close: if gallery is downloaded → [evictImages] → `null`
  List<GalleryImage?>? images;

  Future<void>? _imagesLoadingFuture;

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
    List<GalleryImage?>? images,
    GalleryImage? coverImage,
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
  })  : _onSpeedUpdate = onSpeedUpdate,
        images = images,
        coverImage = coverImage ?? (images == null || images.isEmpty ? null : images[0]);

  /// Lazy-load the full [images] list from DB. Idempotent + concurrent-safe:
  /// concurrent callers share the same [_imagesLoadingFuture]. After evict
  /// ([images] == null), re-calling reloads from DB.
  Future<void> ensureImagesLoaded() async {
    if (images != null) {
      return;
    }
    if (_imagesLoadingFuture != null) {
      return _imagesLoadingFuture!;
    }
    _imagesLoadingFuture = _loadImages().whenComplete(() => _imagesLoadingFuture = null);
    return _imagesLoadingFuture!;
  }

  Future<void> _loadImages() async {
    final List<ImageData> rows = await GalleryImageDao.selectImagesByGalleryId(gid);
    final List<GalleryImage?> loaded = List.generate(pageCount, (_) => null);
    for (final d in rows) {
      if (d.serialNo < pageCount) {
        loaded[d.serialNo] = GalleryImage(
          url: d.url,
          originalImageUrl: d.originalImageUrl,
          path: d.path,
          imageHash: d.imageHash.isEmpty ? null : d.imageHash,
          downloadStatus: DownloadStatus.values[d.downloadStatusIndex],
        );
      }
    }
    images = loaded;
    if (coverImage == null && loaded[0] != null) {
      coverImage = loaded[0];
    }

    /// Sync [GalleryDownloadProgress.hasDownloaded] for incomplete galleries.
    /// Completed galleries derive hasDownloaded on demand (see getter).
    if (downloadProgress.downloadStatus != DownloadStatus.downloaded) {
      downloadProgress._hasDownloaded ??= List.filled(pageCount, false);
      final List<bool> has = downloadProgress._hasDownloaded!;
      for (int i = 0; i < pageCount; i++) {
        has[i] = loaded[i]?.downloadStatus == DownloadStatus.downloaded;
      }
    }
  }

  /// Refcount of active consumers that need the full [images] list resident
  /// for synchronous access (read page, details page, thumbnails page,
  /// super-resolution, etc.). While non-empty, [evictImages] is a no-op —
  /// the list stays resident until the last consumer calls [releaseImages].
  ///
  /// Keyed by an owner label (caller-supplied, e.g. 'ReadPageLogic',
  /// 'SuperResolutionService') so that a blocked evict can log exactly which
  /// consumers are still holding a retain. A single owner may retain multiple
  /// times — its count is the map value.
  ///
  /// The download loop itself does NOT retain — eviction is gated by
  /// `downloadStatus == downloaded` separately, so an incomplete gallery
  /// never evicts regardless of refcount.
  final Map<String, int> _imageResidents = <String, int>{};

  /// Mark that a consumer (read page, detail page, etc.) needs the full
  /// [images] list to stay resident. Pairs with [releaseImages]. Safe to
  /// call multiple times — each call increments the owner's count, each
  /// release decrements. If [images] is currently evicted, triggers a lazy
  /// reload so the consumer can read synchronously after the returned future
  /// completes (or use [ensureImagesLoaded] explicitly for the async wait).
  ///
  /// [owner] should be a stable identifier for debugging — typically the
  /// consumer's runtimeType or a short literal. Identical owner strings
  /// aggregate into a single map entry.
  void retainImages({required String owner}) {
    _imageResidents[owner] = (_imageResidents[owner] ?? 0) + 1;
    if (images == null) {
      ensureImagesLoaded();
    }
  }

  /// Release a retain. When the count drops to 0 AND the gallery is fully
  /// downloaded, evicts the list to bound memory. Incomplete galleries
  /// keep the list — the download loop is still using it.
  ///
  /// [owner] must match the [retainImages] call. Pass `evictIfComplete: false`
  /// for consumers that close while another is expected to take over
  /// imminently (rare).
  void releaseImages({required String owner, bool evictIfComplete = true}) {
    final int? count = _imageResidents[owner];
    if (count == null || count == 0) {
      log.warning('releaseImages called with owner "$owner" but no matching retain on gallery $gid; current owners: ${_ownersSnapshot()}');
      return;
    }
    if (count == 1) {
      _imageResidents.remove(owner);
    } else {
      _imageResidents[owner] = count - 1;
    }
    if (_imageResidents.isEmpty && evictIfComplete && downloadProgress.downloadStatus == DownloadStatus.downloaded) {
      evictImages();
    }
  }

  /// Whether any consumer is currently retaining the [images] list.
  bool get imagesRetained => _imageResidents.isNotEmpty;

  /// Snapshot of current owners + their retain counts, formatted for logs.
  /// E.g. `ReadPageLogic(1), SuperResolutionService(2)`.
  String _ownersSnapshot() {
    return _imageResidents.entries.map((e) => '${e.key}(${e.value})').join(', ');
  }

  /// Release [images] from memory. [coverImage] is retained for list/grid
  /// cover display. No-op while [imagesRetained] is true — eviction is
  /// deferred to the last consumer's [releaseImages] call, and the blocking
  /// owners are logged for debugging.
  ///
  /// Called directly by the download-completion path and by [releaseImages]
  /// when the refcount drains to 0 on a completed gallery.
  void evictImages() {
    if (_imageResidents.isNotEmpty) {
      log.debug('evictImages skipped on gallery $gid: ${_imageResidents.length} owner(s) still retaining: ${_ownersSnapshot()}');
      return;
    }
    log.debug('evictImages on gallery $gid');
    images = null;
  }

  /// Synchronous read — returns null if [images] is not currently resident.
  GalleryImage? imageAtSync(int serialNo) => images?[serialNo];

  /// Async read — triggers [ensureImagesLoaded] if needed.
  Future<GalleryImage?> imageAt(int serialNo) async {
    await ensureImagesLoaded();
    return images?[serialNo];
  }

  /// Write a freshly parsed/created [GalleryImage] at [serialNo]: updates
  /// [images] (if resident) and [coverImage] (if serialNo == 0).
  void upsertImage(int serialNo, GalleryImage image) {
    images ??= List.generate(pageCount, (_) => null);
    images![serialNo] = image;
    if (serialNo == 0) coverImage = image;
  }

  void updateImageStatus(int serialNo, DownloadStatus status) {
    images?[serialNo]?.downloadStatus = status;
    if (serialNo == 0) coverImage?.downloadStatus = status;
  }

  void updateImagePath(int serialNo, String? newPath) {
    images?[serialNo]?.path = newPath;
    if (serialNo == 0) coverImage?.path = newPath;
  }

  void clearImage(int serialNo) {
    images?[serialNo] = null;
    if (serialNo == 0) coverImage = null;
  }

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
    final int rankCmp = groupSortRank(group) - groupSortRank(other.group);
    if (rankCmp != 0) {
      return rankCmp;
    }

    final int groupCmp = group.compareTo(other.group);
    if (groupCmp != 0) {
      return groupCmp;
    }

    final int orderCmp = sortOrder - other.sortOrder;
    if (orderCmp != 0) {
      return orderCmp;
    }

    return other.insertTime.compareTo(insertTime);
  }

  int _parseInsertTimePriority() {
    try {
      final DateTime dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(insertTime);
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

  /// Per-image downloaded flags. Only populated for incomplete galleries
  /// (downloadStatus != downloaded). For completed galleries, the getter
  /// returns a synthesized all-true list on demand — avoids holding a
  /// pageCount-sized List<bool> for every finished gallery in the library.
  List<bool>? _hasDownloaded;

  GalleryDownloadProgress({
    required this.curCount,
    required this.totalCount,
    required this.downloadStatus,
    List<bool>? hasDownloaded,
  }) : _hasDownloaded = hasDownloaded;

  List<bool> get hasDownloaded {
    if (downloadStatus == DownloadStatus.downloaded) {
      return List.filled(totalCount, true);
    }
    return _hasDownloaded ??= List.filled(totalCount, false);
  }

  set hasDownloaded(List<bool> value) => _hasDownloaded = value;

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
