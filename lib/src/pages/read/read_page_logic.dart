import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:path/path.dart' as path;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/pages/read/layout/base/base_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/vertical_list/vertical_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/reader_image_prefetch_queue.dart';
import 'package:jhentai/src/service/reader_pipeline_scheduler.dart';
import 'package:jhentai/src/service/reader_performance_governor.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/eh_executor.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:retry/retry.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:throttling/throttling.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../model/detail_page_info.dart';
import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../model/read_page_info.dart';
import '../../network/eh_request.dart';
import '../../routes/routes.dart';
import '../../service/log.dart';
import '../../service/lan_sharing_runtime.dart';
import '../../service/read_progress_service.dart';
import '../../setting/image_translation_setting.dart';
import '../../setting/preference_setting.dart';
import '../../setting/performance_setting.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/route_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/auto_mode_interval_dialog.dart';
import '../../widget/eh_image.dart';
import '../../widget/image_translation_config_sheet.dart';
import '../../widget/loading_state_indicator.dart';
import '../home_page.dart';
import '../setting/advanced/image_translation/setting_image_translation_page.dart';
import '../setting/keyboard_shortcuts/setting_keyboard_shortcuts_page.dart';
import '../setting/read/setting_read_page.dart';

class ReadPageLogic extends GetxController with WidgetsBindingObserver {
  final String pageId = 'pageId';
  final String layoutId = 'layoutId';
  final String onlineImageId = 'onlineImageId';
  final String parseImageHrefsStateId = 'parseImageHrefsStateId';
  final String parseImageUrlStateId = 'parseImageUrlStateId';
  final String autoModeId = 'autoModeId';
  final String translationMenuId = 'translationMenuId';
  final String batteryId = 'batteryId';
  final String currentTimeId = 'currentTimeId';
  final String topMenuId = 'topMenuId';
  final String bottomMenuId = 'bottomMenuId';
  final String rightBottomInfoId = 'rightBottomInfoId';
  final String pageNoId = 'pageNoId';
  final String thumbnailNoId = 'thumbnailsId';
  final String sliderId = 'sliderId';

  ReadPageState state = ReadPageState();

  String thumbnailItemId(int index) => '$thumbnailNoId::$index';

  BaseLayoutLogic get layoutLogic =>
      effectiveReadDirection == ReadDirection.top2bottomList
          ? Get.find<VerticalListLayoutLogic>()
          : isInListReadDirection
          ? Get.find<HorizontalListLayoutLogic>()
          : isInDoubleColumnReadDirection
          ? Get.find<HorizontalDoubleColumnLayoutLogic>()
          : Get.find<HorizontalPageLayoutLogic>();

  late Timer refreshCurrentTimeAndBatteryLevelTimer;
  late Timer flushReadProgressTimer;

  late Worker toggleTurnPageByVolumeKeyLister;
  late Worker toggleCurrentImmersiveModeLister;
  late Worker showStatusInfoLister;
  late Worker toggleDeviceOrientationLister;
  late Worker readDirectionLister;
  late Worker imageSpaceLister;
  late Worker displayFirstPageAloneListener;
  late Worker enableCustomBrightnessListener;
  late Worker customBrightnessListener;
  late Worker preloadListener;
  late Worker readerEngine2Listener;
  late Worker performanceGovernorListener;
  late Worker progressiveImagePipelineListener;
  late Worker enableBottomMenuListener;
  late Worker orientationSpecificReadDirectionLister;
  late Worker portraitReadDirectionLister;
  late Worker landscapeReadDirectionLister;
  late Worker portraitImageRegionWidthRatioLister;
  late Worker landscapeImageRegionWidthRatioLister;
  late Worker portraitDisplayFirstPageAloneListener;
  late Worker landscapeDisplayFirstPageAloneListener;

  /// Tracks the last known portrait state for orientation-specific read direction
  bool? _lastIsPortrait;

  /// limit the rate of parsing to decrease the lagging of build
  final EHExecutor executor = EHExecutor(
    concurrency: 100,
    rate: const Rate(10, Duration(milliseconds: 1000)),
  );

  /// Parses requests that are already cached without the network rate limit.
  final EHExecutor cacheExecutor = EHExecutor(concurrency: 20);

  /// Thumbnail pages that already have a parse task scheduled/running.
  final Set<int> _parsingHrefPages = <int>{};

  /// Detail pages with an in-flight prefetch triggered by an explicit jump.
  final Set<int> _prefetchingPages = <int>{};

  /// Number of automatic retries performed for each online image load.
  final Map<int, int> _autoRetryCounts = <int, int>{};

  /// One watchdog per visible online image. It is reset by every image loading
  /// progress event and cancelled as soon as the image completes or reloads.
  final Map<int, Timer> _onlineImageProgressWatchdogs = <int, Timer>{};

  /// Translation overlays are hydrated only for pages in this set. Leaving a
  /// viewport releases terminal in-memory results while the persistent cache
  /// remains available for a later visit or app restart.
  Set<int> _visibleTranslationIndices = <int>{};

  /// Session-level parsed results for online galleries, so re-entering the
  /// same gallery reuses already parsed links instead of re-parsing from DB.
  static const int maxSessionCachedGalleries = 20;
  static final Map<String, _SessionParseCache> _sessionParseCache = {};

  final Throttling _thr = Throttling(
    duration: const Duration(milliseconds: 200),
  );

  final int normalPriority = 10000;

  late final ReaderPipelineScheduler readerPipelineScheduler;
  late final ReaderPerformanceGovernor readerPerformanceGovernor;
  late final ReaderImagePrefetchQueue readerImagePrefetchQueue;

  bool inited = false;
  Completer<void> delayInitCompleter = Completer<void>();

  @override
  void onInit() {
    super.onInit();
    readerPipelineScheduler = ReaderPipelineScheduler(
      pageCount: state.readPageInfo.pageCount,
      onPageRequested: _advanceReaderPipeline,
    );
    readerImagePrefetchQueue = ReaderImagePrefetchQueue();
    readerPerformanceGovernor = ReaderPerformanceGovernor(
      onPolicyChanged: _applyReaderPerformancePolicy,
    );
    _restoreSessionCache();
  }

  void _advanceReaderPipeline(int index, ReaderPagePriority priority) {
    if (state.readPageInfo.mode != ReadMode.online) {
      return;
    }
    if (state.thumbnails[index] == null) {
      if (state.parseImageHrefsStates[index] == LoadingState.idle) {
        beginToParseImageHref(index, priority: priority.executorPriority);
      }
      return;
    }
    if (state.images[index] == null &&
        state.parseImageUrlStates[index] == LoadingState.idle) {
      beginToParseImageUrl(index, false, priority: priority.executorPriority);
    }
  }

  void updateReaderViewport(Iterable<int> visibleIndices) {
    final Set<int> nextVisible =
        visibleIndices
            .where(
              (index) => index >= 0 && index < state.readPageInfo.pageCount,
            )
            .toSet();
    final Set<int> leaving = _visibleTranslationIndices.difference(nextVisible);
    for (final int index in leaving) {
      final ImageTranslationRequest? request =
          state.imageTranslationRequests[index];
      if (request != null) {
        imageTranslationService.releaseInMemoryResult(request.cacheKey);
      }
    }
    _visibleTranslationIndices = nextVisible;
    for (final int index in nextVisible) {
      unawaited(_hydrateVisibleTranslation(index));
    }

    if (performanceSetting.enableReaderEngine2.isFalse) {
      return;
    }
    readerPipelineScheduler.updateViewport(visibleIndices);
    _syncImagePrefetchPlan();
  }

  Future<void> _hydrateVisibleTranslation(int index) async {
    try {
      await layoutLogic.hydrateTranslation(index);
    } catch (e, stack) {
      // Hydration is opportunistic. A missing image file must not interrupt
      // the reader or make an OCR/translation task appear completed.
      log.warning('Failed to hydrate translation for page $index: $e');
      log.trace(stack);
    }
  }

  void _applyReaderPerformancePolicy(ReaderPerformancePolicy policy) {
    executor.concurrency = policy.parseConcurrency;
    cacheExecutor.concurrency = policy.cacheConcurrency;
    readerImagePrefetchQueue.configure(
      concurrency: policy.imagePrefetchConcurrency,
    );
    readerPipelineScheduler.configure(
      lookAhead: policy.lookAhead,
      lookBehind: policy.lookBehind,
    );
    _syncImagePrefetchPlan();
  }

  void _syncImagePrefetchPlan() {
    if (performanceSetting.enableReaderEngine2.isFalse ||
        state.readPageInfo.mode != ReadMode.online) {
      readerImagePrefetchQueue.clear();
      return;
    }
    readerImagePrefetchQueue.updatePlan(
      readerPipelineScheduler.plan,
      (int index) => state.images[index]?.url,
    );
  }

  void _syncPerformanceGovernor() {
    if (performanceSetting.enablePerformanceGovernor.isTrue) {
      readerPerformanceGovernor.start();
    } else {
      readerPerformanceGovernor.stop();
    }
  }

  void _restoreSessionCache() {
    final String? galleryUrl = state.readPageInfo.galleryUrl;
    if (state.readPageInfo.mode != ReadMode.online || galleryUrl == null) {
      return;
    }

    final _SessionParseCache? cached = _sessionParseCache[galleryUrl];
    if (cached == null ||
        cached.thumbnails.length != state.thumbnails.length ||
        cached.images.length != state.images.length) {
      return;
    }

    state.thumbnails = List.of(cached.thumbnails);
    state.images = List.of(cached.images);
    state.thumbnailsCountPerPage = cached.thumbnailsCountPerPage;
    log.debug('Restore read page session cache for $galleryUrl');
  }

  void _saveSessionCache() {
    final String? galleryUrl = state.readPageInfo.galleryUrl;
    if (state.readPageInfo.mode != ReadMode.online || galleryUrl == null) {
      return;
    }

    _sessionParseCache[galleryUrl] = _SessionParseCache(
      thumbnails: List.of(state.thumbnails),
      images: List.of(state.images),
      thumbnailsCountPerPage: state.thumbnailsCountPerPage,
    );
    if (_sessionParseCache.length > maxSessionCachedGalleries) {
      _sessionParseCache.remove(_sessionParseCache.keys.first);
    }
  }

  @override
  void onReady() {
    super.onReady();

    WidgetsBinding.instance.addObserver(this);

    Timer(const Duration(milliseconds: 120), () {
      if (inited && !delayInitCompleter.isCompleted) {
        delayInitCompleter.complete();
      }
    });

    /// Turn page by volume keys. The reason for not use [KeyboardListener]: https://github.com/flutter/flutter/issues/71144
    listen2VolumeKeys();

    applyCurrentImmersiveMode();

    updateDeviceOrientation();

    /// Listen to turn page by volume key change
    toggleTurnPageByVolumeKeyLister = ever(
      readSetting.enablePageTurnByVolumeKeys,
      (_) => listen2VolumeKeys(),
    );

    /// Listen to immersive mode change
    toggleCurrentImmersiveModeLister = ever(
      readSetting.enableImmersiveMode,
      (_) => applyCurrentImmersiveMode(),
    );

    /// Listen to device orientation change
    toggleDeviceOrientationLister = ever(
      readSetting.deviceDirection,
      (_) => updateDeviceOrientation(),
    );

    /// Listen to read direction change
    readDirectionLister = ever(
      readSetting.readDirection,
      (_) => onEffectiveSettingChanged(),
    );

    imageSpaceLister = ever(readSetting.imageSpace, (_) {
      updateSafely([layoutId]);
    });

    displayFirstPageAloneListener = ever(
      readSetting.displayFirstPageAlone,
      (_) => _syncDisplayFirstPageAloneToState(),
    );
    portraitDisplayFirstPageAloneListener = ever(
      readSetting.portraitDisplayFirstPageAlone,
      (_) {
        if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
            isPortrait) {
          _syncDisplayFirstPageAloneToState();
        }
      },
    );
    landscapeDisplayFirstPageAloneListener = ever(
      readSetting.landscapeDisplayFirstPageAlone,
      (_) {
        if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
            !isPortrait) {
          _syncDisplayFirstPageAloneToState();
        }
      },
    );

    /// Listen to orientation-specific settings changes for rebuild
    orientationSpecificReadDirectionLister = ever(
      readSetting.enableOrientationSpecificReadDirection,
      (_) => onEffectiveSettingChanged(),
    );
    portraitReadDirectionLister = ever(readSetting.portraitReadDirection, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
          isPortrait) {
        onEffectiveSettingChanged();
      }
    });
    landscapeReadDirectionLister = ever(readSetting.landscapeReadDirection, (
      _,
    ) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
          !isPortrait) {
        onEffectiveSettingChanged();
      }
    });
    portraitImageRegionWidthRatioLister = ever(
      readSetting.portraitImageRegionWidthRatio,
      (_) {
        if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
            isPortrait) {
          updateSafely([layoutId]);
        }
      },
    );
    landscapeImageRegionWidthRatioLister = ever(
      readSetting.landscapeImageRegionWidthRatio,
      (_) {
        if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
            !isPortrait) {
          updateSafely([layoutId]);
        }
      },
    );

    if (!GetPlatform.isDesktop) {
      state.battery.batteryLevel.then((value) => state.batteryLevel = value);
    }

    /// refresh current time and battery level info; the per-second timer is
    /// only useful while the status info is shown in the read menu
    refreshCurrentTimeAndBatteryLevelTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshCurrentTimeAndBatteryLevel(),
    );
    showStatusInfoLister = ever(
      readSetting.showStatusInfo,
      (_) => _syncStatusInfoTimer(),
    );
    if (readSetting.showStatusInfo.isFalse) {
      refreshCurrentTimeAndBatteryLevelTimer.cancel();
    }

    flushReadProgressTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flushReadProgress(),
    );

    if (readSetting.keepScreenAwakeWhenReading.isTrue) {
      WakelockPlus.enable();
    }

    if (GetPlatform.isMobile && readSetting.enableCustomReadBrightness.isTrue) {
      applyCurrentBrightness();
    }
    enableCustomBrightnessListener = ever(
      readSetting.enableCustomReadBrightness,
      (_) {
        if (GetPlatform.isMobile &&
            readSetting.enableCustomReadBrightness.isTrue) {
          applyCurrentBrightness();
        } else {
          resetBrightness();
        }
      },
    );
    customBrightnessListener = ever(readSetting.customBrightness, (_) {
      applyCurrentBrightness();
    });

    enableBottomMenuListener = ever(readSetting.enableBottomMenu, (_) {
      updateSafely([topMenuId]);
    });

    preloadListener = everAll([
      readSetting.preloadPageCountLocal,
      readSetting.preloadPageCount,
      readSetting.preloadDistanceLocal,
      readSetting.preloadDistance,
    ], (_) => updateSafely([layoutId]));
    readerEngine2Listener = ever(performanceSetting.enableReaderEngine2, (_) {
      if (performanceSetting.enableReaderEngine2.isFalse) {
        readerPipelineScheduler.clear();
        readerImagePrefetchQueue.clear();
      } else {
        readerPipelineScheduler.updateViewport([
          state.readPageInfo.currentImageIndex,
        ]);
        _syncImagePrefetchPlan();
      }
      updateSafely([layoutId]);
    });
    performanceGovernorListener = ever(
      performanceSetting.enablePerformanceGovernor,
      (_) => _syncPerformanceGovernor(),
    );
    progressiveImagePipelineListener = ever(
      performanceSetting.enableProgressiveImagePipeline,
      (_) => updateSafely([layoutId]),
    );
    _syncPerformanceGovernor();

    _syncDisplayFirstPageAloneToState();

    inited = true;
    if (!delayInitCompleter.isCompleted) {
      delayInitCompleter.complete();
    }
  }

  @override
  void onClose() {
    super.onClose();

    _cancelAllOnlineImageProgressWatchdogs();

    readerPipelineScheduler.dispose();
    readerImagePrefetchQueue.dispose();
    readerPerformanceGovernor.stop();

    // Leaving the gallery must stop any in-flight translation batch so the
    // OCR/API work is not carried on in the background.
    imageTranslationService.cancelBatch();
    for (final ImageTranslationRequest request
        in state.imageTranslationRequests.values) {
      imageTranslationService.releaseInMemoryResult(request.cacheKey);
    }
    _visibleTranslationIndices = <int>{};

    _saveSessionCache();

    WidgetsBinding.instance.removeObserver(this);

    state.focusNode.dispose();
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    toggleTurnPageByVolumeKeyLister.dispose();
    toggleCurrentImmersiveModeLister.dispose();
    showStatusInfoLister.dispose();
    readDirectionLister.dispose();
    imageSpaceLister.dispose();
    flushReadProgressTimer.cancel();
    displayFirstPageAloneListener.dispose();
    enableCustomBrightnessListener.dispose();
    customBrightnessListener.dispose();
    preloadListener.dispose();
    readerEngine2Listener.dispose();
    performanceGovernorListener.dispose();
    progressiveImagePipelineListener.dispose();
    enableBottomMenuListener.dispose();
    orientationSpecificReadDirectionLister.dispose();
    portraitReadDirectionLister.dispose();
    landscapeReadDirectionLister.dispose();
    portraitImageRegionWidthRatioLister.dispose();
    landscapeImageRegionWidthRatioLister.dispose();
    portraitDisplayFirstPageAloneListener.dispose();
    landscapeDisplayFirstPageAloneListener.dispose();

    restoreVolumeListener();

    restoreImmersiveMode();

    restoreDeviceOrientation();

    _flushReadProgress();

    if (readSetting.enableCustomReadBrightness.isTrue) {
      resetBrightness();
    }

    Get.delete<VerticalListLayoutLogic>(force: true);
    Get.delete<HorizontalListLayoutLogic>(force: true);
    Get.delete<HorizontalPageLayoutLogic>(force: true);
    Get.delete<HorizontalDoubleColumnLayoutLogic>(force: true);

    executor.close();
    cacheExecutor.close();

    WakelockPlus.disable();

    EHImageAnimationGateRegistry.clear();
  }

  void beginToParseImageHref(int index, {int? priority}) {
    if (state.thumbnails[index] != null) {
      return;
    }
    if (state.parseImageHrefsStates[index] == LoadingState.loading) {
      return;
    }

    final int imagesPerDetailPage = state.thumbnailsCountPerPage;
    final int requestPageIndex = index ~/ imagesPerDetailPage;
    if (_parsingHrefPages.contains(requestPageIndex)) {
      return;
    }

    state.parseImageHrefsStates[index] = LoadingState.loading;
    updateSafely(['$parseImageHrefsStateId::$index']);
    _parsingHrefPages.add(requestPageIndex);

    _scheduleHrefParse(
      index,
      requestPageIndex,
      imagesPerDetailPage,
      priority ?? normalPriority,
    );
  }

  Future<void> _scheduleHrefParse(
    int index,
    int requestPageIndex,
    int imagesPerDetailPage,
    int priority,
  ) async {
    bool cached = false;
    bool probed = false;
    try {
      cached = await ehRequest.hasCachedDetailPage(
        state.readPageInfo.galleryUrl!,
        requestPageIndex,
      );
      probed = true;
    } catch (e) {
      log.warning('Check detail page cache failed, use rate limited parse', e);
      cached = false;
    }

    Future<void> task() async {
      try {
        if (priority < normalPriority &&
            !readerPipelineScheduler.isDetailPagePlanned(
              requestPageIndex,
              imagesPerDetailPage,
            )) {
          state.parseImageHrefsStates[index] = LoadingState.idle;
          updateSafely(['$parseImageHrefsStateId::$index']);
          return;
        }
        await parseImageHref(index, alreadyProbed: probed && !cached);
      } finally {
        _parsingHrefPages.remove(requestPageIndex);
      }
    }

    try {
      if (cached) {
        await cacheExecutor.scheduleTask(priority, task);
      } else {
        /// limit the rate of parsing to decrease the lagging of build
        await executor.scheduleTask(priority, task);
      }
    } catch (e, stackTrace) {
      _parsingHrefPages.remove(requestPageIndex);
      log.error(
        'Unexpected thumbnail href parse failure, detail page: $requestPageIndex',
        e,
        stackTrace,
      );
      if (!isClosed) {
        _markHrefPageError(requestPageIndex, 'parsePageFailed'.tr);
      }
    }
  }

  /// User explicitly jumped to [imageIndex]: warm the page cache for the
  /// target detail page and the two pages on each side. Prefetches bypass the
  /// rate-limited [executor] so the burst is not delayed by other parsing, and
  /// simply fill the cache; the normal lazy parse still fills thumbnails when
  /// the user reaches those pages (then served from cache).
  void prefetchDetailPagesAround(int imageIndex) {
    if (state.readPageInfo.mode != ReadMode.online ||
        state.readPageInfo.galleryUrl == null) {
      return;
    }
    final int pageCount = state.readPageInfo.pageCount;
    final int thumbnailsCountPerPage = state.thumbnailsCountPerPage;
    if (pageCount <= 0 || thumbnailsCountPerPage <= 0) {
      return;
    }
    final int maxPageIndex = (pageCount - 1) ~/ thumbnailsCountPerPage;
    final int targetPageIndex = imageIndex ~/ thumbnailsCountPerPage;
    final int from = max(0, targetPageIndex - 2);
    final int to = min(maxPageIndex, targetPageIndex + 2);
    for (int pageIndex = from; pageIndex <= to; pageIndex++) {
      _prefetchDetailPage(pageIndex);
    }
  }

  void _prefetchDetailPage(int pageIndex) {
    if (_prefetchingPages.contains(pageIndex) ||
        _parsingHrefPages.contains(pageIndex) ||
        _isDetailPageParsed(pageIndex)) {
      return;
    }
    _prefetchingPages.add(pageIndex);
    unawaited(_doPrefetchDetailPage(pageIndex));
  }

  bool _isDetailPageParsed(int pageIndex) {
    final int start = pageIndex * state.thumbnailsCountPerPage;
    final int end = min(
      start + state.thumbnailsCountPerPage - 1,
      state.readPageInfo.pageCount - 1,
    );
    for (int i = start; i <= end; i++) {
      if (state.thumbnails[i] == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _doPrefetchDetailPage(int pageIndex) async {
    try {
      await ehRequest.requestDetailPage(
        galleryUrl: state.readPageInfo.galleryUrl!,
        thumbnailsPageIndex: pageIndex,
        parser: EHSpiderParser.detailPage2RangeAndThumbnails,
      );
    } catch (e) {
      log.warning('Prefetch detail page $pageIndex failed', e);
    } finally {
      _prefetchingPages.remove(pageIndex);
    }
  }

  Future<void> parseImageHref(int index, {bool alreadyProbed = false}) async {
    if (state.thumbnails[index] != null) {
      state.parseImageHrefsStates[index] = LoadingState.idle;
      updateSafely(['$onlineImageId::$index']);
      return;
    }

    log.trace(
      'Begin to load Thumbnail $index with page size: ${state.thumbnailsCountPerPage}',
    );

    int requestPageIndex = index ~/ state.thumbnailsCountPerPage;

    DetailPageInfo detailPageInfo;
    try {
      detailPageInfo = await retry(
        () => ehRequest.requestDetailPage(
          galleryUrl: state.readPageInfo.galleryUrl!,
          thumbnailsPageIndex: requestPageIndex,
          alreadyProbed: alreadyProbed,
          parser: EHSpiderParser.detailPage2RangeAndThumbnails,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioException,
        onRetry:
            (e) => log.error(
              'Get thumbnails error!',
              (e as DioException).errorMsg,
            ),
      );
    } on DioException catch (_) {
      _markHrefPageError(requestPageIndex, 'parsePageFailed'.tr);
      return;
    } on EHSiteException catch (e) {
      _markHrefPageError(requestPageIndex, e.message);
      return;
    }

    state.parseImageHrefsStates[index] = LoadingState.idle;

    /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
    /// For example, default setting is 40, but some gallerys' thumbnails has only high quality thumbnails, which results in 20.
    bool thumbnailsCountPerPageChanged =
        state.thumbnailsCountPerPage != detailPageInfo.thumbnailsCountPerPage;
    state.thumbnailsCountPerPage = detailPageInfo.thumbnailsCountPerPage;

    for (
      int i = detailPageInfo.imageNoFrom;
      i <= detailPageInfo.imageNoTo;
      i++
    ) {
      state.thumbnails[i] =
          detailPageInfo.thumbnails[i - detailPageInfo.imageNoFrom];
    }

    /// If we changed profile setting in EH site and have cached in JHenTai, we need to remove the cache to get the latest page info before re-parsing
    if (state.thumbnails[index] == null) {
      log.download(
        'Parse image hrefs error, thumbnails count per page is not equal to default setting, parse again. Thumbnails count per page: ${detailPageInfo.thumbnailsCountPerPage}, changed: $thumbnailsCountPerPageChanged',
      );
      await ehRequest.removeCacheByGalleryUrlAndPage(
        state.readPageInfo.galleryUrl!,
        requestPageIndex,
      );
      _parsingHrefPages.remove(requestPageIndex);
      return beginToParseImageHref(index);
    }

    updateSafely([
      for (
        int i = detailPageInfo.imageNoFrom;
        i <= detailPageInfo.imageNoTo;
        i++
      ) ...['$onlineImageId::$i', thumbnailItemId(i)],
    ]);
    _saveSessionCache();
    if (performanceSetting.enableReaderEngine2.isTrue) {
      readerPipelineScheduler.refresh();
    }
  }

  void _markHrefPageError(int requestPageIndex, String message) {
    state.parseImageHrefErrorMsg = message;
    final int pageStart = requestPageIndex * state.thumbnailsCountPerPage;
    final int pageEnd = min(
      pageStart + state.thumbnailsCountPerPage - 1,
      state.readPageInfo.pageCount - 1,
    );

    final List<String> ids = [];
    for (int i = pageStart; i <= pageEnd; i++) {
      if (state.thumbnails[i] != null) {
        continue;
      }
      state.parseImageHrefsStates[i] = LoadingState.error;
      ids.add('$parseImageHrefsStateId::$i');
    }
    if (ids.isNotEmpty) {
      update(ids);
    }
  }

  void beginToParseImageUrl(
    int index,
    bool reParse, {
    String? reloadKey,
    int? priority,
  }) {
    if (state.parseImageUrlStates[index] == LoadingState.loading) {
      return;
    }

    state.parseImageUrlStates[index] = LoadingState.loading;
    updateSafely(['$parseImageUrlStateId::$index']);

    unawaited(
      _scheduleUrlParse(index, reParse, reloadKey, priority ?? normalPriority),
    );
  }

  Future<void> _scheduleUrlParse(
    int index,
    bool reParse,
    String? reloadKey,
    int priority,
  ) async {
    try {
      if (reParse) {
        await executor.scheduleTask(
          priority,
          () => parseImageUrl(index, reParse, reloadKey),
        );
        return;
      }

      bool cached = false;
      bool probed = false;
      final String? href = state.thumbnails[index]?.replacedMPVHref(index + 1);
      if (href != null) {
        final GalleryImage? lanImage = await lanSharingRuntime.fetchCachedImage(
          href,
          // The gallery context lets a trusted host serve the page from its
          // DOWNLOADED copy, not just the online image cache.
          galleryUrl: state.readPageInfo.galleryUrl,
          pageIndex: index,
          sourceDeviceId: state.readPageInfo.sourceDeviceId,
        );
        if (lanImage != null) {
          state.images[index] = lanImage;
          state.parseImageUrlStates[index] = LoadingState.success;
          updateSafely(['$onlineImageId::$index']);
          _syncImagePrefetchPlan();
          return;
        }
        try {
          cached = await ehRequest.hasCachedImagePage(
            href,
            reloadKey: reloadKey,
          );
          probed = true;
        } catch (e) {
          log.warning(
            'Check image page cache failed, use rate limited parse',
            e,
          );
          cached = false;
        }
      }

      Future<void> task() {
        if (priority < normalPriority &&
            !readerPipelineScheduler.isPlanned(index)) {
          state.parseImageUrlStates[index] = LoadingState.idle;
          updateSafely(['$parseImageUrlStateId::$index']);
          return Future.value();
        }
        return parseImageUrl(
          index,
          reParse,
          reloadKey,
          alreadyProbed: probed && !cached,
        );
      }

      if (cached) {
        await cacheExecutor.scheduleTask(priority, task);
      } else {
        await executor.scheduleTask(priority, task);
      }
    } catch (e, stackTrace) {
      log.error(
        'Unexpected image URL parse failure, index: $index',
        e,
        stackTrace,
      );
      if (!isClosed) {
        state.parseImageUrlStates[index] = LoadingState.error;
        state.parseImageUrlErrorMsg[index] = 'parseURLFailed'.tr;
        updateSafely(['$parseImageUrlStateId::$index']);
      }
    }
  }

  Future<void> parseImageUrl(
    int index,
    bool reParse,
    String? reloadKey, {
    bool alreadyProbed = false,
  }) async {
    GalleryImage image;
    try {
      image = await retry(
        () => requestImage(
          index,
          reParse,
          reloadKey,
          alreadyProbed: alreadyProbed,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioException,
        onRetry:
            (e) => log.error(
              'Parse gallery image failed, index: ${index.toString()}',
              (e as DioException).errorMsg,
            ),
      );
    } on DioException catch (_) {
      state.parseImageUrlStates[index] = LoadingState.error;
      state.parseImageUrlErrorMsg[index] = 'parseURLFailed'.tr;
      updateSafely(['$parseImageUrlStateId::$index']);
      return;
    } on EHParseException catch (e) {
      state.parseImageUrlStates[index] = LoadingState.error;
      state.parseImageUrlErrorMsg[index] = e.message.tr;
      updateSafely(['$parseImageUrlStateId::$index']);
      return;
    } on EHSiteException catch (e) {
      state.parseImageUrlStates[index] = LoadingState.error;
      state.parseImageUrlErrorMsg[index] = e.message.tr;
      updateSafely(['$parseImageUrlStateId::$index']);
      return;
    }

    state.images[index] = image;
    final String? href = state.thumbnails[index]?.replacedMPVHref(index + 1);
    if (href != null) {
      unawaited(lanSharingRuntime.recordImagePage(href, image));
    }
    state.parseImageUrlStates[index] = LoadingState.success;
    updateSafely(['$onlineImageId::$index']);
    _syncImagePrefetchPlan();
  }

  Future<GalleryImage> requestImage(
    int index,
    bool reParse,
    String? reloadKey, {
    bool alreadyProbed = false,
  }) {
    return ehRequest.requestImagePage(
      state.thumbnails[index]!.replacedMPVHref(index + 1),
      reloadKey: reloadKey,
      alreadyProbed: alreadyProbed,
      parser: EHSpiderParser.imagePage2GalleryImage,
      useCacheIfAvailable: !reParse,
    );
  }

  Future<void> reloadImage(int index) async {
    _cancelOnlineImageProgressWatchdog(index);
    String? reloadKey;
    if (state.images[index] != null) {
      reloadKey = state.images[index]!.reloadKey;
      final String url = effectiveEHImageUrl(state.images[index]!.url);
      await clearDiskCachedImage(url, cacheKey: normalizedImageCacheKey(url));
    }
    // The reloaded image is a different picture; drop any stale translation
    // overlay (and its result) so old blocks/text are not drawn over it.
    final oldRequest = state.imageTranslationRequests.remove(index);
    if (oldRequest != null) {
      imageTranslationService.removeResult(oldRequest.cacheKey);
    }
    state.images[index] = null;
    state.loadedOnlineImageIndices.remove(index);
    state.failedOnlineImageIndices.remove(index);
    beginToParseImageUrl(index, true, reloadKey: reloadKey);
    updateSafely(['$onlineImageId::$index']);
  }

  /// Automatically reload an online image after a load failure. The retry
  /// re-parses the image page so a fresh image URL is used.
  void autoRetryFailedImage(int index) {
    _scheduleAutoRetry(
      index,
      delay: const Duration(milliseconds: 500),
      reason: 'load failure',
    );
  }

  /// Records that an online image is still making progress. If no more loading
  /// updates arrive before the configured timeout, retry it through the normal
  /// reparse path. A gallery image is retried up to the configured limit.
  void watchOnlineImageLoading(int index) {
    if (readSetting.enableImageTimeoutRetry.isFalse ||
        _autoRetryCount(index) >= readSetting.imageTimeoutRetryCount.value) {
      _cancelOnlineImageProgressWatchdog(index);
      return;
    }

    _cancelOnlineImageProgressWatchdog(index);
    late final Timer watchdog;
    watchdog = Timer(
      Duration(milliseconds: readSetting.imageTimeoutRetryInterval.value),
      () {
        if (isClosed || _onlineImageProgressWatchdogs[index] != watchdog) {
          return;
        }
        _onlineImageProgressWatchdogs.remove(index);
        if (readSetting.enableImageTimeoutRetry.isTrue) {
          _scheduleAutoRetry(index, reason: 'loading progress timeout');
        }
      },
    );
    _onlineImageProgressWatchdogs[index] = watchdog;
  }

  void _scheduleAutoRetry(
    int index, {
    Duration delay = Duration.zero,
    required String reason,
  }) {
    final int retryCount = _autoRetryCount(index);
    final int maxRetryCount = readSetting.imageTimeoutRetryCount.value;
    if (retryCount >= maxRetryCount) {
      return;
    }
    _autoRetryCounts[index] = retryCount + 1;

    Future.delayed(delay, () {
      if (isClosed) {
        return;
      }
      log.info(
        'Auto retry online image, index: $index, reason: $reason, attempt: ${retryCount + 1}/$maxRetryCount',
      );
      reloadImage(index);
    });
  }

  void _cancelOnlineImageProgressWatchdog(int index) {
    _onlineImageProgressWatchdogs.remove(index)?.cancel();
  }

  void _cancelAllOnlineImageProgressWatchdogs() {
    for (final Timer watchdog in _onlineImageProgressWatchdogs.values) {
      watchdog.cancel();
    }
    _onlineImageProgressWatchdogs.clear();
  }

  int _autoRetryCount(int index) => _autoRetryCounts[index] ?? 0;

  /// Called when image bytes finish loading, so a later failure of the same
  /// image can trigger one automatic retry again.
  void markOnlineImageLoaded(int index) {
    _cancelOnlineImageProgressWatchdog(index);
    _autoRetryCounts.remove(index);
    if (!state.loadedOnlineImageIndices.add(index)) {
      return;
    }

    // completedWidgetBuilder runs while the image widget is building. Defer
    // the rebuild that removes the thumbnail layer until that frame finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        updateSafely(['$onlineImageId::$index']);
      }
    });
  }

  /// Retry loading failed online images, covering a scope decided by
  /// [readSetting.failedImageRetryScope]. [fromIndex] is the image the user
  /// tapped; with the "current page and after" scope it also reloads every
  /// failed image at or after that index, and with "all" every failed image.
  void retryFailedImages({required int fromIndex}) {
    final FailedImageRetryScope scope = readSetting.failedImageRetryScope.value;

    if (scope == FailedImageRetryScope.retrySingleImage) {
      reloadImage(fromIndex);
      return;
    }

    final List<int> targets = [];
    for (int i = 0; i < state.readPageInfo.pageCount; i++) {
      if (scope == FailedImageRetryScope.retryCurrentPageAndAfter &&
          i < fromIndex) {
        continue;
      }
      final bool isFailed =
          state.parseImageUrlStates[i] == LoadingState.error ||
          state.failedOnlineImageIndices.contains(i);
      if (i == fromIndex || isFailed) {
        targets.add(i);
      }
    }

    log.info('Retry failed images, scope: $scope, targets: $targets');
    for (int index in targets) {
      reloadImage(index);
    }
  }

  void listen2VolumeKeys() {
    if (readSetting.enablePageTurnByVolumeKeys.isFalse) {
      volumeService.cancelListen();
      return;
    }

    volumeService.listen((VolumeEventType type) {
      if (type == VolumeEventType.volumeUp) {
        layoutLogic.toPrev();
      } else if (type == VolumeEventType.volumeDown) {
        layoutLogic.toNext();
      }
    });
  }

  void restoreVolumeListener() {
    volumeService.cancelListen();
  }

  /// If [immersiveMode], switch to [SystemUiMode.immersiveSticky], otherwise reset to [SystemUiMode.edgeToEdge]
  void applyCurrentImmersiveMode() {
    if (GetPlatform.isWindows) {
      clearImageContainerSized();
      updateSafely([pageId]);
    }

    if (readSetting.enableImmersiveMode.isTrue) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void restoreImmersiveMode() {
    if (GetPlatform.isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void applyCurrentBrightness() {
    if (GetPlatform.isMobile && readSetting.enableCustomReadBrightness.isTrue) {
      ScreenBrightness().setScreenBrightness(
        readSetting.customBrightness.value.toDouble() / 100,
      );
    }
  }

  void resetBrightness() {
    if (GetPlatform.isMobile) {
      ScreenBrightness().resetScreenBrightness();
    }
  }

  void updateDeviceOrientation() {
    if (!GetPlatform.isMobile) {
      return;
    }

    if (readSetting.deviceDirection.value == DeviceDirection.followSystem) {
      restoreDeviceOrientation();
    }
    if (readSetting.deviceDirection.value == DeviceDirection.landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (readSetting.deviceDirection.value == DeviceDirection.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void restoreDeviceOrientation() {
    if (!GetPlatform.isMobile) {
      return;
    }

    SystemChrome.setPreferredOrientations([]);
  }

  @override
  void didChangeMetrics() {
    if (!GetPlatform.isMobile) {
      return;
    }

    if (readSetting.enableOrientationSpecificReadDirection.isFalse) {
      return;
    }

    if (readSetting.deviceDirection.value != DeviceDirection.followSystem) {
      return;
    }

    final Size size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final bool isPortrait = size.height >= size.width;

    if (_lastIsPortrait == null) {
      _lastIsPortrait = isPortrait;
      return;
    }

    if (_lastIsPortrait == isPortrait) {
      return;
    }

    _lastIsPortrait = isPortrait;

    final ReadDirection targetDirection =
        isPortrait
            ? readSetting.portraitReadDirection.value
            : readSetting.landscapeReadDirection.value;
    final String directionName = targetDirection.name.tr;
    final String orientationKey = isPortrait ? 'portrait' : 'landscape';
    toast(
      '${'autoSwitchedReadDirection'.tr}: $directionName (${orientationKey.tr})',
    );

    onEffectiveSettingChanged();
  }

  void onEffectiveSettingChanged() {
    clearImageContainerSized();
    state.readPageInfo.initialIndex = state.readPageInfo.currentImageIndex;
    _syncDisplayFirstPageAloneToState();
    updateSafely([layoutId]);
  }

  void _syncDisplayFirstPageAloneToState() {
    final effective = effectiveDisplayFirstPageAlone;
    if (state.displayFirstPageAlone != effective) {
      state.displayFirstPageAlone = effective;
      layoutLogic.toggleDisplayFirstPageAlone();
      updateSafely([topMenuId, bottomMenuId]);
    }
  }

  bool get isPortrait {
    if (readSetting.deviceDirection.value == DeviceDirection.portrait) {
      return true;
    }
    if (readSetting.deviceDirection.value == DeviceDirection.landscape) {
      return false;
    }
    final size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    return size.height >= size.width;
  }

  ReadDirection get effectiveReadDirection {
    if (readSetting.enableOrientationSpecificReadDirection.isFalse ||
        !GetPlatform.isMobile) {
      return readSetting.readDirection.value;
    }
    if (isPortrait) {
      return readSetting.portraitReadDirection.value;
    }
    return readSetting.landscapeReadDirection.value;
  }

  void saveReadDirection(ReadDirection value) {
    if (readSetting.enableOrientationSpecificReadDirection.isTrue &&
        GetPlatform.isMobile) {
      if (isPortrait) {
        readSetting.savePortraitReadDirection(value);
      } else {
        readSetting.saveLandscapeReadDirection(value);
      }
    } else {
      readSetting.saveReadDirection(value);
    }
  }

  int get effectiveImageRegionWidthRatio {
    if (!GetPlatform.isMobile ||
        readSetting.enableOrientationSpecificReadDirection.isFalse) {
      return readSetting.imageRegionWidthRatio.value;
    }
    return isPortrait
        ? readSetting.portraitImageRegionWidthRatio.value
        : readSetting.landscapeImageRegionWidthRatio.value;
  }

  bool get effectiveDisplayFirstPageAlone {
    if (!GetPlatform.isMobile ||
        readSetting.enableOrientationSpecificReadDirection.isFalse) {
      return readSetting.displayFirstPageAlone.value;
    }
    return isPortrait
        ? readSetting.portraitDisplayFirstPageAlone.value
        : readSetting.landscapeDisplayFirstPageAlone.value;
  }

  bool get isInListReadDirection =>
      ReadSetting.isListDirection(effectiveReadDirection);

  bool get isInDoubleColumnReadDirection =>
      ReadSetting.isDoubleColumnDirection(effectiveReadDirection);

  bool get isInSinglePageReadDirection =>
      ReadSetting.isSinglePageDirection(effectiveReadDirection);

  bool get isInFitWidthReadDirection =>
      ReadSetting.isFitWidthDirection(effectiveReadDirection);

  bool get isInRight2LeftDirection =>
      ReadSetting.isRight2LeftDirection(effectiveReadDirection);

  void toggleMenu() {
    state.isMenuOpen = !state.isMenuOpen;
    update([topMenuId, bottomMenuId, rightBottomInfoId]);
  }

  Future<void> toggleAutoMode() async {
    if (state.autoMode) {
      return closeAutoMode();
    }

    bool? begin = await Get.dialog(const AutoModeIntervalDialog());
    if (begin == null || !begin) {
      return;
    }

    enterAutoMode();
  }

  void enterAutoMode() {
    state.autoMode = true;
    update([autoModeId]);
    layoutLogic.enterAutoMode();
  }

  void closeAutoMode() {
    state.autoMode = false;
    update([autoModeId]);
    layoutLogic.closeAutoMode();
  }

  void tapLeftRegion() {
    if (!inited) {
      return;
    }

    if (readSetting.disablePageTurningOnTap.isTrue) {
      return;
    }

    if (state.isScrolling) {
      return;
    }

    if (readSetting.reverseTurnPageDirection.isTrue) {
      toRight();
    } else {
      toLeft();
    }
  }

  void tapRightRegion() {
    if (!inited) {
      return;
    }
    if (readSetting.disablePageTurningOnTap.isTrue) {
      return;
    }

    if (state.isScrolling) {
      return;
    }

    if (readSetting.reverseTurnPageDirection.isTrue) {
      toLeft();
    } else {
      toRight();
    }
  }

  void tapCenterRegion() {
    if (state.isScrolling) {
      return;
    }

    toggleMenu();
  }

  /// click right arrow key
  void toLeft() {
    layoutLogic.toLeft();
  }

  /// click right arrow key
  void toRight() {
    layoutLogic.toRight();
  }

  /// to prev image or screen
  void toPrev() {
    layoutLogic.toPrev();
  }

  /// to next image or screen
  void toNext() {
    layoutLogic.toNext();
  }

  void handleM() {
    toggleDisplayFirstPageAlone();
  }

  void jump2ImageIndex(int pageIndex) {
    layoutLogic.jump2ImageIndex(pageIndex);
    prefetchDetailPagesAround(pageIndex);
  }

  void handleSlide(double pageNo) {
    state.readPageInfo.currentImageIndex = (pageNo - 1).toInt();
    update([sliderId, pageNoId]);
  }

  void handleSlideEnd(double pageNo) {
    jump2ImageIndex((pageNo - 1).toInt());
  }

  /// Sync thumbnails after user scrolling to image whose index is [targetImageIndex]
  void syncThumbnails(int targetImageIndex) {
    if (readSetting.showThumbnails.isFalse) {
      return;
    }

    int? firstThumbnailIndex = getCurrentVisibleThumbnails().firstOrNull?.index;
    int? lastThumbnailIndex = getCurrentVisibleThumbnails().lastOrNull?.index;
    if (firstThumbnailIndex == null) {
      return;
    }

    /// No more thumbnails, do not scroll more
    if (lastThumbnailIndex == state.readPageInfo.pageCount - 1 &&
        targetImageIndex > firstThumbnailIndex) {
      return;
    }

    /// If a new scroll starts before previous scroll end, the previous scroll will be cancelled. So if user keeps scrolling
    /// the list, the scroll of the thumbnail list will be delayed until the user stops scrolling. We use Throttling to avoid.
    _thr.throttle(() {
      scrollThumbnailsToIndex(targetImageIndex);
    });
  }

  void scrollThumbnailsToIndex(int index) {
    if (!isClosed) {
      state.thumbnailsScrollController.scrollTo(
        index: max(0, index - 2),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void handleTapSuperResolutionButton() {
    state.useSuperResolution = !state.useSuperResolution;
    log.info('toggle super resolution mode: ${state.useSuperResolution}');
    updateSafely([topMenuId]);
    layoutLogic.updateSafely([BaseLayoutLogic.pageId]);
  }

  String getSuperResolutionProgress() {
    int gid = state.readPageInfo.gid!;
    SuperResolutionType type =
        state.readPageInfo.mode == ReadMode.downloaded
            ? SuperResolutionType.gallery
            : SuperResolutionType.archive;
    SuperResolutionInfo? superResolutionInfo = superResolutionService.get(
      gid,
      type,
    );

    if (superResolutionInfo == null) {
      return '';
    }

    return '(${superResolutionInfo.imageStatuses.where((status) => status == SuperResolutionStatus.success).length}/${superResolutionInfo.imageStatuses.length})';
  }

  void toggleDisplayFirstPageAlone() {
    log.info('toggleDisplayFirstPageAlone->${!state.displayFirstPageAlone}');
    state.displayFirstPageAlone = !state.displayFirstPageAlone;

    layoutLogic.toggleDisplayFirstPageAlone();
    updateSafely([topMenuId, bottomMenuId]);
  }

  List<ItemPosition> getCurrentVisibleThumbnails() {
    return filterAndSortItems(
      state.thumbnailPositionsListener.itemPositions.value,
    );
  }

  /// for some reason like slow loading of some image, [ItemPositions] may be not in index order, and even some of
  /// them are not in viewport
  List<ItemPosition> filterAndSortItems(Iterable<ItemPosition> positions) {
    positions =
        positions
            .where(
              (item) =>
                  !(item.itemTrailingEdge < 0 || item.itemLeadingEdge > 1),
            )
            .toList();
    (positions as List<ItemPosition>).sort((a, b) => a.index - b.index);
    return positions;
  }

  /// Tracks the last read index actually written, so the periodic flush and
  /// the per-page-boundary flush only touch the storage when progress moved.
  int _lastFlushedProgressIndex = -1;

  void recordReadProgress(int index) {
    /// Only react when the visible page boundary changed; the listener can
    /// fire every scroll frame with the same index.
    if (state.readPageInfo.currentImageIndex == index) {
      return;
    }
    state.readPageInfo.currentImageIndex = index;

    /// The thumbnail strip is only on screen while the menu is open; skip its
    /// rebuild when the menu is closed.
    if (state.isMenuOpen) {
      update([sliderId, pageNoId, thumbnailNoId]);
    } else {
      update([sliderId, pageNoId]);
    }

    /// The index changed, so this is a page boundary: persist the progress now
    /// instead of waiting for the periodic 5s flush.
    unawaited(_flushReadProgress());
  }

  void _refreshCurrentTimeAndBatteryLevel() {
    if (readSetting.showStatusInfo.isFalse) {
      return;
    }
    if (!GetPlatform.isDesktop) {
      state.battery.batteryLevel.then((value) {
        state.batteryLevel = value;
        update([batteryId]);
      });
    }
    update([currentTimeId]);
  }

  /// Start or stop the per-second status info timer depending on whether the
  /// status info (current time / battery level) is shown in the read menu.
  void _syncStatusInfoTimer() {
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    if (readSetting.showStatusInfo.isFalse) {
      return;
    }
    refreshCurrentTimeAndBatteryLevelTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshCurrentTimeAndBatteryLevel(),
    );
  }

  Future<void> _flushReadProgress() async {
    final int index = state.readPageInfo.currentImageIndex;
    if (index == _lastFlushedProgressIndex) {
      return;
    }
    _lastFlushedProgressIndex = index;
    readProgressService.updateReadProgress(
      state.readPageInfo.readProgressRecordStorageKey,
      index,
    );
  }

  void clearImageContainerSized() {
    state.imageContainerSizes = List.generate(
      state.readPageInfo.pageCount,
      (_) => null,
    );
  }

  Future<void> openReadSetting(BuildContext context) async {
    if (styleSetting.isInDesktopLayout || styleSetting.isInTabletLayout) {
      await _showReadSettingDrawer(context);
    } else {
      await _pushReadSettingPage();
    }
  }

  Future<void> openImageTranslationConfig(BuildContext context) async {
    restoreImmersiveMode();
    if (styleSetting.isInDesktopLayout || styleSetting.isInTabletLayout) {
      await _showImageTranslationDrawer(context);
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder:
            (sheetContext) => FractionallySizedBox(
              heightFactor: 0.92,
              child: ImageTranslationConfigSheet(
                onTranslateCurrentImage: () => _translateCurrentImage(context),
              ),
            ),
      );
    }
    applyCurrentImmersiveMode();
    state.focusNode.requestFocus();
  }

  Future<void> _showImageTranslationDrawer(BuildContext context) async {
    final GlobalKey<NavigatorState> configNavigatorKey =
        GlobalKey<NavigatorState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        double width = MediaQuery.of(context).size.width * 0.55;
        if (width < 360) {
          width = 360;
        }
        if (width > 600) {
          width = 600;
        }
        final Widget content = Navigator(
          key: configNavigatorKey,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return _buildDrawerRoute(
                settings: settings,
                useCupertino: preferenceSetting.enableSwipeBackGesture.isTrue,
                builder:
                    (_) => ImageTranslationConfigSheet(
                      onTranslateCurrentImage: () {
                        Navigator.of(dialogContext).pop();
                        _translateCurrentImage(context);
                      },
                      onClose: () => Navigator.of(dialogContext).pop(),
                      onOpenAdvancedSettings:
                          () => configNavigatorKey.currentState?.pushNamed(
                            '/advanced',
                          ),
                    ),
              );
            }
            if (settings.name == '/advanced') {
              return _buildDrawerRoute(
                settings: settings,
                useCupertino: preferenceSetting.enableSwipeBackGesture.isTrue,
                builder: (_) => const SettingImageTranslationPage(),
              );
            }
            return null;
          },
        );
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Material(
              color: Theme.of(dialogContext).colorScheme.surface,
              elevation: 16,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Future<void> _translateCurrentImage(BuildContext context) async {
    final int startIndex = state.readPageInfo.currentImageIndex;
    final bool translateSubsequent =
        imageTranslationSetting.translateSubsequentPages.value;
    final List<int> order =
        translateSubsequent
            ? await _buildTranslationOrder(startIndex)
            : [startIndex];
    final int generation = imageTranslationService.beginBatch(order.length);
    try {
      for (
        int orderPosition = 0;
        orderPosition < order.length;
        orderPosition++
      ) {
        final int index = order[orderPosition];
        if (imageTranslationService.isCancelRequested) {
          _cancelRemainingBatchPages(order, orderPosition, generation);
          break;
        }

        final RecognizedImage? recognized = await _safeRecognize(
          index,
          context,
        );
        final ImageTranslationRequest? request =
            state.imageTranslationRequests[index];
        final String cacheKey = request?.cacheKey ?? _batchPageKey(index);
        if (recognized != null) {
          try {
            await layoutLogic.translateRecognizedImage(
              index,
              context,
              recognized,
            );
          } catch (e, stack) {
            log.warning('Image translation failed for page $index: $e');
            log.trace(stack);
            imageTranslationService.markOcrError(
              cacheKey,
              'TRANSLATION_TASK_FAILED',
            );
          }
        } else {
          final ImageTranslationResult result = imageTranslationService
              .resultFor(cacheKey);
          if (!result.isTerminal) {
            imageTranslationService.markOcrError(
              cacheKey,
              'TRANSLATION_TASK_FAILED',
            );
          }
        }
        imageTranslationService.recordBatchResult(
          cacheKey,
          generation: generation,
        );
      }
    } finally {
      imageTranslationService.endBatch(generation);
    }
  }

  String _batchPageKey(int index) => 'batch-page:$index';

  void _cancelRemainingBatchPages(
    List<int> order,
    int fromPosition,
    int generation,
  ) {
    if (!imageTranslationService.isCurrentBatch(generation)) return;
    for (int position = fromPosition; position < order.length; position++) {
      final int index = order[position];
      final String cacheKey =
          state.imageTranslationRequests[index]?.cacheKey ??
          _batchPageKey(index);
      imageTranslationService.markCanceled(cacheKey);
      imageTranslationService.recordBatchResult(
        cacheKey,
        generation: generation,
      );
    }
  }

  /// Orders the pages to translate: the current page first, then the other
  /// pages (only those from the current page onward — earlier pages are not
  /// re-translated) whose images are already ready, then the pages whose
  /// images are still loading (translated last so a loading page doesn't stall
  /// the batch).
  Future<List<int>> _buildTranslationOrder(int startIndex) async {
    final List<int> indices = [
      for (var i = startIndex; i < state.readPageInfo.pageCount; i++) i,
    ];
    // Resolve the disk-cache directory once for all online-mode probes.
    final String? cacheDirectory =
        state.readPageInfo.mode == ReadMode.online
            ? await getExtendedImageDiskCacheDirectory()
            : null;
    final List<bool> readyFlags = await Future.wait(
      indices.map((index) => _isPageImageReady(index, cacheDirectory)),
    );
    final List<int> ready = [];
    final List<int> deferred = [];
    for (var i = 0; i < indices.length; i++) {
      (readyFlags[i] ? ready : deferred).add(indices[i]);
    }
    return [...ready, ...deferred];
  }

  /// Whether the page's source image is already available locally so
  /// translating it won't wait on a slow network fetch.
  Future<bool> _isPageImageReady(int index, [String? cacheDirectory]) async {
    final GalleryImage? image = state.images[index];
    if (image == null) {
      return false;
    }
    final ReadMode mode = state.readPageInfo.mode;
    if (mode != ReadMode.online) {
      // Local images are immediately available (no network wait), so ordering
      // only needs the current page first. A missing file fails gracefully
      // during translation.
      return image.path != null;
    }
    // Online: ready when the image is already in the extended_image disk cache
    // (the reader / prefetch queue fills it as pages are viewed).
    final String url = effectiveEHImageUrl(image.url);
    final String cacheKey = normalizedImageCacheKey(url);
    final String directory =
        cacheDirectory ?? await getExtendedImageDiskCacheDirectory();
    return io.File(path.join(directory, cacheKey)).exists();
  }

  /// Runs a page's OCR stage. Any exception is converted into a terminal
  /// observable status so the batch never counts an OCR exception as success.
  Future<RecognizedImage?> _safeRecognize(
    int index,
    BuildContext context,
  ) async {
    try {
      return await layoutLogic.recognizeImage(index, context);
    } catch (e, stack) {
      log.warning('Image translation OCR failed for page $index: $e');
      log.trace(stack);
      final String cacheKey =
          state.imageTranslationRequests[index]?.cacheKey ??
          _batchPageKey(index);
      imageTranslationService.markOcrError(cacheKey, 'OCR_FAILED');
      return null;
    }
  }

  /// Toggles whether the inline translation overlay is drawn on the images.
  void toggleImageTranslationOverlay() {
    state.showImageTranslationOverlay = !state.showImageTranslationOverlay;
    updateSafely([translationMenuId]);
    layoutLogic.updateSafely([BaseLayoutLogic.pageId]);
  }

  /// Re-runs recognition and translation for the current page, bypassing the
  /// persistent translation cache.
  Future<void> retranslateCurrentImage(BuildContext context) async {
    await layoutLogic.translateImage(
      state.readPageInfo.currentImageIndex,
      context,
      force: true,
    );
  }

  /// Starts the translation flow for the current page (honouring the
  /// translate-subsequent-pages scope setting).
  Future<void> startImageTranslation(BuildContext context) =>
      _translateCurrentImage(context);

  Future<void> _pushReadSettingPage() async {
    restoreImmersiveMode();
    toRoute(Routes.settingRead, id: fullScreen)?.then((_) {
      applyCurrentImmersiveMode();
      state.focusNode.requestFocus();
    });
  }

  Future<void> _showReadSettingDrawer(BuildContext context) async {
    restoreImmersiveMode();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        double width = MediaQuery.of(context).size.width * 0.55;
        if (width < 360) {
          width = 360;
        }
        if (width > 600) {
          width = 600;
        }
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) {
                final Widget content = Navigator(
                  key: const Key('readPageLogic'),
                  initialRoute: '/',
                  onGenerateRoute: (settings) {
                    final bool useCupertino =
                        preferenceSetting.enableSwipeBackGesture.isTrue;
                    if (settings.name == '/') {
                      return _buildDrawerRoute(
                        builder: (_) => SettingReadPage(),
                        settings: settings,
                        useCupertino: useCupertino,
                      );
                    }
                    if (settings.name == '/keyboard_shortcuts') {
                      return _buildDrawerRoute(
                        builder: (_) => const SettingKeyboardShortcutsPage(),
                        settings: settings,
                        useCupertino: useCupertino,
                      );
                    }
                    return null;
                  },
                );

                if (ThemeConfig.isApple) {
                  final ColorScheme colorScheme = Theme.of(context).colorScheme;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                      child: content,
                    ),
                  );
                }

                return Material(elevation: 16, child: content);
              },
            ),
          ),
        );
      },
    );

    applyCurrentImmersiveMode();
    state.focusNode.requestFocus();
  }

  Route _buildDrawerRoute({
    required Widget Function(BuildContext) builder,
    required RouteSettings settings,
    required bool useCupertino,
  }) {
    if (useCupertino) {
      return PageRouteBuilder(
        pageBuilder: (context, __, ___) => builder(context),
        transitionsBuilder:
            (_, animation, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
              child: child,
            ),
        settings: settings,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, __, ___) => builder(context),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
      settings: settings,
    );
  }
}

class _SessionParseCache {
  final List<GalleryThumbnail?> thumbnails;
  final List<GalleryImage?> images;
  final int thumbnailsCountPerPage;

  _SessionParseCache({
    required this.thumbnails,
    required this.images,
    required this.thumbnailsCountPerPage,
  });
}
