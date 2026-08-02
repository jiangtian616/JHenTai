import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_download_dialog.dart';
import 'package:jhentai/src/widget/eh_favorite_sort_order_dialog.dart';

import '../../database/database.dart';
import '../../enum/config_enum.dart';
import '../../exception/eh_site_exception.dart';
import '../../model/gallery.dart';
import '../../model/search_config.dart';
import '../../service/archive_download_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/local_config_service.dart';
import '../../setting/user_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../service/log.dart';
import '../../utils/snack_util.dart';
import '../../widget/loading_state_indicator.dart';
import '../base/base_page_logic.dart';
import 'favorite_page_state.dart';

class FavoritePageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  bool get autoLoadNeedLogin => true;

  @override
  final FavoritePageState state = FavoritePageState();

  final String batchDownloadProgressId = 'batchDownloadProgressId';

  /// max retry attempts after an initial failure (page load & download task)
  static const int _maxRetryTimes = 5;

  /// wait between page loads (matches the normal inter-page delay)
  static const Duration _pageLoadWait = Duration(seconds: 2);

  /// wait between retry attempts for local enqueue failures
  static const Duration _retryWait = Duration(milliseconds: 500);

  /// save favorites to disk every N pages to avoid O(n²) write overhead
  static const int _favoritesSaveInterval = 5;

  /// resume window for breakpoint continuation
  static const Duration _resumeTimeout = Duration(minutes: 30);

  /// drives the per-second failure countdown refresh
  Timer? _failureCountdownTimer;

  @override
  void onClose() {
    _stopFailureCountdown();
    super.onClose();
  }

  Future<void> handleTapDownloadAll() async {
    if (state.isBatchDownloading) {
      toast('batchDownloadInProgress'.tr);
      return;
    }

    if (!userSetting.hasLoggedIn()) {
      toast('needLoginToOperate'.tr);
      return;
    }

    // Try to resume an interrupted batch within the 30-minute window.
    Map<String, dynamic>? savedProgress = await _loadProgress();
    bool canResume = false;
    if (savedProgress != null) {
      try {
        DateTime lastUpdateTime =
            DateTime.parse(savedProgress['lastUpdateTime'] as String);
        canResume = DateTime.now().difference(lastUpdateTime) < _resumeTimeout;
      } catch (e) {
        canResume = false;
      }
    }

    if (!canResume) {
      if (savedProgress != null) {
        await _clearAll();
      }
      _stopFailureCountdown();
      state.batchDownloadFailureTime = null;
      state.batchDownloadFailurePhase = '';

      ({String group, bool downloadOriginalImage})? result = await Get.dialog(
        EHDownloadDialog(
          title: 'chooseGroup'.tr,
          currentGroup: downloadSetting.defaultGalleryGroup.value,
          candidates: galleryDownloadService.allGroups,
          showDownloadOriginalImageCheckBox: userSetting.hasLoggedIn(),
          downloadOriginalImage:
              downloadSetting.downloadOriginalImageByDefault.value,
        ),
      );
      if (result == null) {
        return;
      }

      await _runBatchDownload(
        targetGroup: result.group,
        downloadOriginalImage: result.downloadOriginalImage,
        savedNextGid: null,
        savedFavorites: null,
        startPhase: 'loadingFavorites',
      );
      return;
    }

    // Resume path: reuse saved settings, skip the dialog.
    String targetGroup = savedProgress!['targetGroup'] as String;
    bool downloadOriginalImage = savedProgress['downloadOriginalImage'] as bool;
    String phase = savedProgress['phase'] as String;
    String? savedNextGid = savedProgress['nextGid'] as String?;

    List<Gallery>? savedFavorites = await _loadFavorites();
    if (savedFavorites == null) {
      // favorites data lost → cannot resume safely, start fresh next time
      await _clearAll();
      _stopFailureCountdown();
      state.batchDownloadFailureTime = null;
      state.batchDownloadFailurePhase = '';
      toast('batchDownloadWaitInterrupted'.tr);
      return;
    }

    toast('batchDownloadResumed'.tr);
    _stopFailureCountdown();
    state.batchDownloadFailureTime = null;
    state.batchDownloadFailurePhase = '';

    await _runBatchDownload(
      targetGroup: targetGroup,
      downloadOriginalImage: downloadOriginalImage,
      savedNextGid: phase == 'loadingFavorites' ? savedNextGid : null,
      savedFavorites: savedFavorites,
      startPhase: phase,
    );
  }

  Future<void> _runBatchDownload({
    required String targetGroup,
    required bool downloadOriginalImage,
    required String? savedNextGid,
    required List<Gallery>? savedFavorites,
    required String startPhase,
  }) async {
    state.isBatchDownloading = true;
    updateSafely([batchDownloadProgressId]);

    try {
      List<Gallery> allFavorites;

      if (startPhase == 'downloading') {
        allFavorites = savedFavorites ?? [];
      } else {
        state.batchDownloadPhase = 'loadingFavorites';
        state.batchDownloadTotalCount = savedFavorites?.length ?? 0;
        state.batchDownloadCurrentCount = 0;
        updateSafely([batchDownloadProgressId]);

        List<Gallery>? loaded = await _loadAllFavoritesWithResume(
          savedNextGid: savedNextGid,
          existing: savedFavorites ?? [],
          targetGroup: targetGroup,
          downloadOriginalImage: downloadOriginalImage,
        );
        if (loaded == null) {
          // loading failed after all retries → breakpoint resume triggered,
          // countdown already shown by _handleLoadingFailure.
          return;
        }
        allFavorites = loaded;
      }

      List<Gallery> toDownload = allFavorites.where((g) {
        return !galleryDownloadService.containGallery(g.gid) &&
            !archiveDownloadService.containArchive(g.gid);
      }).toList();

      if (toDownload.isEmpty) {
        toast('noNewFavoritesToDownload'.tr);
        await _clearAll();
        return;
      }

      // persist transition to downloading phase (keeps resume window fresh)
      await _saveProgress(
        phase: 'downloading',
        targetGroup: targetGroup,
        downloadOriginalImage: downloadOriginalImage,
        nextGid: null,
        failureTime: null,
      );

      state.batchDownloadPhase = 'downloading';
      state.batchDownloadTotalCount = toDownload.length;
      state.batchDownloadCurrentCount = 0;
      updateSafely([batchDownloadProgressId]);

      int successCount = await _downloadGalleriesWithResume(
        toDownload: toDownload,
        targetGroup: targetGroup,
        downloadOriginalImage: downloadOriginalImage,
      );

      toast(
          '${'batchDownloadCompleted'.tr} ($successCount/${toDownload.length})');
      await _clearAll();
    } catch (e) {
      log.error('batch download favorites failed', e);
      snack('failed'.tr, e.toString());
    } finally {
      state.isBatchDownloading = false;
      state.batchDownloadPhase = '';
      state.batchDownloadTotalCount = 0;
      state.batchDownloadCurrentCount = 0;
      updateSafely([batchDownloadProgressId]);
    }
  }

  /// Loads all favorites starting from [savedNextGid], appending to [existing].
  /// Returns null if loading failed after all retries (breakpoint resume set up).
  Future<List<Gallery>?> _loadAllFavoritesWithResume({
    required String? savedNextGid,
    required List<Gallery> existing,
    required String targetGroup,
    required bool downloadOriginalImage,
  }) async {
    List<Gallery> allFavorites = List.of(existing);
    String? nextGid = savedNextGid;
    int pageCount = 0;

    while (true) {
      GalleryPageInfo galleryPage;
      try {
        galleryPage = await _getGalleryPageWithRetry(nextGid);
      } catch (e) {
        await _handleLoadingFailure(
          nextGid: nextGid,
          loadedFavorites: allFavorites,
          targetGroup: targetGroup,
          downloadOriginalImage: downloadOriginalImage,
        );
        return null;
      }

      allFavorites.addAll(galleryPage.gallerys);
      nextGid = galleryPage.nextGid;
      pageCount++;

      state.batchDownloadTotalCount = allFavorites.length;
      updateSafely([batchDownloadProgressId]);

      await _saveProgress(
        phase: 'loadingFavorites',
        targetGroup: targetGroup,
        downloadOriginalImage: downloadOriginalImage,
        nextGid: nextGid,
        failureTime: null,
      );

      /// Save favorites every N pages or when loading is complete,
      /// instead of every page, to avoid O(n²) serialization overhead.
      if (pageCount % _favoritesSaveInterval == 0 || nextGid == null) {
        await _saveFavorites(allFavorites);
      }

      if (nextGid == null) {
        break;
      }
      await Future.delayed(_pageLoadWait);
    }

    return allFavorites;
  }

  /// Fetches a favorites page, retrying up to [_maxRetryTimes] times with
  /// [_pageLoadWait] between attempts (same as the normal inter-page delay).
  Future<GalleryPageInfo> _getGalleryPageWithRetry(String? nextGid) async {
    int attempt = 0;
    while (true) {
      try {
        return await getGalleryPage(nextGid: nextGid);
      } catch (e) {
        attempt++;
        if (attempt > _maxRetryTimes) {
          log.error(
              'load favorites page failed after $_maxRetryTimes retries, nextGid: $nextGid',
              e);
          rethrow;
        }
        log.error(
            'load favorites page failed (retry $attempt/$_maxRetryTimes), nextGid: $nextGid',
            e);
        await Future.delayed(_pageLoadWait);
      }
    }
  }

  Future<int> _downloadGalleriesWithResume({
    required List<Gallery> toDownload,
    required String targetGroup,
    required bool downloadOriginalImage,
  }) async {
    int successCount = 0;
    final DateTime baseInsertTime = DateTime.now();
    for (int i = 0; i < toDownload.length; i++) {
      Gallery gallery = toDownload[i];

      bool ok = await _downloadGalleryWithRetry(
        gallery,
        targetGroup: targetGroup,
        downloadOriginalImage: downloadOriginalImage,
        insertTime: baseInsertTime.subtract(Duration(seconds: i)),
      );
      if (ok) {
        successCount++;
      }

      state.batchDownloadCurrentCount = i + 1;
      updateSafely([batchDownloadProgressId]);

      // refresh the resume window periodically for long download phases
      if (i > 0 && i % 10 == 0) {
        await _saveProgress(
          phase: 'downloading',
          targetGroup: targetGroup,
          downloadOriginalImage: downloadOriginalImage,
          nextGid: null,
          failureTime: null,
        );
      }
    }
    return successCount;
  }

  /// Adds a single gallery to the download queue, retrying up to
  /// [_maxRetryTimes] times with [_retryWait] between attempts. Returns
  /// false if all retries are exhausted (the gallery is then skipped).
  Future<bool> _downloadGalleryWithRetry(
    Gallery gallery, {
    required String targetGroup,
    required bool downloadOriginalImage,
    required DateTime insertTime,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        GalleryDownloadedData galleryDownloadedData = GalleryDownloadedData(
          gid: gallery.gid,
          token: gallery.token,
          title: gallery.title,
          category: gallery.category,
          pageCount: gallery.pageCount ?? 0,
          galleryUrl: gallery.galleryUrl.url,
          uploader: gallery.uploader,
          publishTime: gallery.publishTime,
          downloadStatusIndex: DownloadStatus.downloading.index,
          downloadOriginalImage: downloadOriginalImage,
          sortOrder: 0,
          groupName: targetGroup,
          insertTime: insertTime.toString(),
          priority: GalleryDownloadService.defaultDownloadGalleryPriority,
          tags: tagMap2TagString(gallery.tags),
          tagRefreshTime: DateTime.now().toString(),
        );
        galleryDownloadService.downloadGallery(galleryDownloadedData);
        return true;
      } catch (e) {
        attempt++;
        if (attempt > _maxRetryTimes) {
          log.error(
              'batch download gallery failed after $_maxRetryTimes retries: ${gallery.gid}',
              e);
          return false;
        }
        log.error(
            'batch download gallery failed (retry $attempt/$_maxRetryTimes): ${gallery.gid}',
            e);
        await Future.delayed(_retryWait);
      }
    }
  }

  /// Persist failure state, start the 30-min countdown, and notify the user.
  /// The batch download loop is left to the caller's finally block to reset.
  Future<void> _handleLoadingFailure({
    required String? nextGid,
    required List<Gallery> loadedFavorites,
    required String targetGroup,
    required bool downloadOriginalImage,
  }) async {
    DateTime now = DateTime.now();
    state.batchDownloadFailureTime = now;
    state.batchDownloadFailurePhase = 'loadingFavorites';

    await _saveProgress(
      phase: 'loadingFavorites',
      targetGroup: targetGroup,
      downloadOriginalImage: downloadOriginalImage,
      nextGid: nextGid,
      failureTime: now,
    );
    await _saveFavorites(loadedFavorites);

    _startFailureCountdown();
    snack('batchDownloadLoadingFailed'.tr, 'batchDownloadRetryExhausted'.tr);
  }

  void _startFailureCountdown() {
    _failureCountdownTimer?.cancel();
    _failureCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.batchDownloadFailureTime == null) {
        _stopFailureCountdown();
        return;
      }
      if (failureCountdownRemainingSeconds <= 0) {
        _stopFailureCountdown();
        state.batchDownloadFailureTime = null;
        state.batchDownloadFailurePhase = '';
        _clearAll();
        updateSafely([batchDownloadProgressId]);
        return;
      }
      updateSafely([batchDownloadProgressId]);
    });
    updateSafely([batchDownloadProgressId]);
  }

  void _stopFailureCountdown() {
    _failureCountdownTimer?.cancel();
    _failureCountdownTimer = null;
  }

  /// Called by the "Interrupt Wait" button: cancel countdown, clear state,
  /// so the next "Download All" starts fresh.
  Future<void> handleInterruptWait() async {
    _stopFailureCountdown();
    state.batchDownloadFailureTime = null;
    state.batchDownloadFailurePhase = '';
    await _clearAll();
    updateSafely([batchDownloadProgressId]);
    toast('batchDownloadWaitInterrupted'.tr);
  }

  int get failureCountdownRemainingSeconds {
    if (state.batchDownloadFailureTime == null) {
      return 0;
    }
    int remaining = _resumeTimeout.inSeconds -
        DateTime.now().difference(state.batchDownloadFailureTime!).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  String get failureCountdownFormatted {
    int s = failureCountdownRemainingSeconds;
    int minutes = s ~/ 60;
    int seconds = s % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _saveProgress({
    required String phase,
    required String targetGroup,
    required bool downloadOriginalImage,
    required String? nextGid,
    required DateTime? failureTime,
  }) async {
    await localConfigService.write(
      configKey: ConfigEnum.favoriteBatchDownloadProgress,
      value: jsonEncode({
        'phase': phase,
        'lastUpdateTime': DateTime.now().toIso8601String(),
        'failureTime': failureTime?.toIso8601String(),
        'targetGroup': targetGroup,
        'downloadOriginalImage': downloadOriginalImage,
        'nextGid': nextGid,
      }),
    );
  }

  Future<void> _saveFavorites(List<Gallery> favorites) async {
    await localConfigService.write(
      configKey: ConfigEnum.favoriteBatchDownloadFavorites,
      value: jsonEncode(favorites.map((g) => g.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>?> _loadProgress() async {
    String? json = await localConfigService.read(
        configKey: ConfigEnum.favoriteBatchDownloadProgress);
    if (json == null) {
      return null;
    }
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      log.error('decode batch download progress failed', e);
      return null;
    }
  }

  Future<List<Gallery>?> _loadFavorites() async {
    String? json = await localConfigService.read(
        configKey: ConfigEnum.favoriteBatchDownloadFavorites);
    if (json == null) {
      return null;
    }
    try {
      List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Gallery.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log.error('decode batch download favorites failed', e);
      return null;
    }
  }

  Future<void> _clearAll() async {
    await localConfigService.delete(
        configKey: ConfigEnum.favoriteBatchDownloadProgress);
    await localConfigService.delete(
        configKey: ConfigEnum.favoriteBatchDownloadFavorites);
  }

  Future<void> handleChangeSortOrder() async {
    if (state.refreshState == LoadingState.loading) {
      return;
    }

    FavoriteSortOrder? result = await Get.dialog(
        EHFavoriteSortOrderDialog(init: state.favoriteSortOrder));
    if (result == null) {
      return;
    }

    if (state.refreshState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;

    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.seek = DateTime.now();
    state.totalCount = null;
    state.favoriteSortOrder = null;

    jump2Top();

    updateSafely();

    try {
      await ehRequest.requestChangeFavoriteSortOrder(result,
          parser: EHSpiderParser.galleryPage2GalleryPageInfo);
    } on DioException catch (e) {
      /// handle with domain fronting, manually load more
      if (e.response?.statusCode == 403 && e.response!.redirects.isNotEmpty) {
        return loadMore(checkLoadingState: false);
      }

      log.error('change favorite sort order fail', e.message);
      snack('failed'.tr, e.message ?? '');
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('change favorite sort order fail', e.message);
      snack('failed'.tr, e.message);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } catch (e) {
      log.error('change favorite sort order fail', e.toString);
      snack('failed'.tr, e.toString());
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    return loadMore(checkLoadingState: false);
  }

  @override
  Future<void> saveSearchConfig(SearchConfig searchConfig) async {
    await localConfigService.write(
      configKey: ConfigEnum.searchConfig,
      subConfigKey: searchConfigKey,
      value: jsonEncode(searchConfig.copyWith(keyword: '', tags: [])),
    );
  }

  /// Retry count for loadMore auto-retry on transient failures.
  static const int _loadMoreMaxRetry = 3;
  static const Duration _loadMoreRetryWait = Duration(seconds: 2);

  /// Override loadMore to add auto-retry on network failures.
  /// After [_loadMoreMaxRetry] attempts, falls back to the normal error state
  /// (with tap-to-retry) so the user can manually retry.
  @override
  Future<void> loadMore({bool checkLoadingState = true}) async {
    if (checkLoadingState && state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely([loadingStateId]);

    GalleryPageInfo? galleryPage;
    Object? lastError;

    for (int attempt = 1; attempt <= _loadMoreMaxRetry; attempt++) {
      try {
        galleryPage = await getGalleryPage(nextGid: state.nextGid);
        break;
      } on DioException catch (e) {
        lastError = e;
        log.error(
            'loadMore failed (attempt $attempt/$_loadMoreMaxRetry)', e.errorMsg);
      } on EHSiteException catch (e) {
        lastError = e;
        log.error(
            'loadMore failed (attempt $attempt/$_loadMoreMaxRetry)', e.message);
      } catch (e) {
        lastError = e;
        log.error(
            'loadMore failed (attempt $attempt/$_loadMoreMaxRetry)', e.toString());
      }

      if (attempt < _loadMoreMaxRetry) {
        await Future.delayed(_loadMoreRetryWait);
      }
    }

    if (galleryPage == null) {
      // All retries exhausted → show error state with tap-to-retry.
      String errorMsg = lastError is DioException
          ? lastError.errorMsg ?? ''
          : lastError.toString();
      snack('getGallerysFailed'.tr, errorMsg, isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys);

    state.gallerys.addAll(gallerys);
    state.totalCount = galleryPage.totalCount;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;

    if (state.nextGid == null &&
        state.prevGid == null &&
        state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }
}
