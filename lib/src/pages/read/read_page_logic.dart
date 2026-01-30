import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/read/layout/base/base_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/vertical_list/vertical_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/utils/eh_executor.dart';
import 'package:retry/retry.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:throttling/throttling.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../model/detail_page_info.dart';
import '../../model/gallery_image.dart';
import '../../model/read_page_info.dart';
import '../../network/eh_request.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../service/log.dart';
import '../../widget/auto_mode_interval_dialog.dart';
import '../../widget/loading_state_indicator.dart';
import '../../service/read_progress_service.dart';

class ReadPageLogic extends GetxController {
  final String pageId = 'pageId';
  final String layoutId = 'layoutId';
  final String onlineImageId = 'onlineImageId';
  final String parseImageHrefsStateId = 'parseImageHrefsStateId';
  final String parseImageUrlStateId = 'parseImageUrlStateId';
  final String autoModeId = 'autoModeId';
  final String batteryId = 'batteryId';
  final String currentTimeId = 'currentTimeId';
  final String topMenuId = 'topMenuId';
  final String bottomMenuId = 'bottomMenuId';
  final String rightBottomInfoId = 'rightBottomInfoId';
  final String pageNoId = 'pageNoId';
  final String thumbnailNoId = 'thumbnailsId';
  final String sliderId = 'sliderId';

  ReadPageState state = ReadPageState();

  BaseLayoutLogic get layoutLogic => readSetting.readDirection.value == ReadDirection.top2bottomList
      ? Get.find<VerticalListLayoutLogic>()
      : readSetting.isInListReadDirection
          ? Get.find<HorizontalListLayoutLogic>()
          : readSetting.isInDoubleColumnReadDirection
              ? Get.find<HorizontalDoubleColumnLayoutLogic>()
              : Get.find<HorizontalPageLayoutLogic>();

  late Timer refreshCurrentTimeAndBatteryLevelTimer;
  late Timer flushReadProgressTimer;

  late Worker toggleTurnPageByVolumeKeyLister;
  late Worker toggleCurrentImmersiveModeLister;
  late Worker toggleDeviceOrientationLister;
  late Worker readDirectionLister;
  late Worker imageSpaceLister;
  late Worker displayFirstPageAloneListener;
  late Worker enableCustomBrightnessListener;
  late Worker customBrightnessListener;
  late Worker preloadListener;

  /// limit the rate of parsing to decrease the lagging of build
  final EHExecutor executor = EHExecutor(
    concurrency: 100,
    rate: const Rate(10, Duration(milliseconds: 1000)),
  );
  final Throttling _thr = Throttling(duration: const Duration(milliseconds: 200));

  final int normalPriority = 10000;

  bool inited = false;
  Completer<void> delayInitCompleter = Completer<void>();

  @override
  void onReady() {
    super.onReady();

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
    toggleTurnPageByVolumeKeyLister = ever(readSetting.enablePageTurnByVolumeKeys, (_) => listen2VolumeKeys());

    /// Listen to immersive mode change
    toggleCurrentImmersiveModeLister = ever(readSetting.enableImmersiveMode, (_) => applyCurrentImmersiveMode());

    /// Listen to device orientation change
    toggleDeviceOrientationLister = ever(readSetting.deviceDirection, (_) => updateDeviceOrientation());

    /// Listen to read direction change
    readDirectionLister = ever(readSetting.readDirection, (_) {
      clearImageContainerSized();
      state.readPageInfo.initialIndex = state.readPageInfo.currentImageIndex;
      updateSafely([layoutId]);
    });

    imageSpaceLister = ever(readSetting.imageSpace, (_) {
      updateSafely([layoutId]);
    });

    displayFirstPageAloneListener = ever(readSetting.displayFirstPageAlone, (value) {
      if (state.displayFirstPageAlone != value) {
        state.displayFirstPageAlone = value;
        layoutLogic.toggleDisplayFirstPageAlone();
        updateSafely([topMenuId, bottomMenuId]);
      }
    });

    if (!GetPlatform.isDesktop) {
      state.battery.batteryLevel.then((value) => state.batteryLevel = value);
    }

    /// refresh current time and battery level info
    refreshCurrentTimeAndBatteryLevelTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!GetPlatform.isDesktop) {
          state.battery.batteryLevel.then((value) {
            state.batteryLevel = value;
            update([batteryId]);
          });
        }
        update([currentTimeId]);
      },
    );

    flushReadProgressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _flushReadProgress());

    if (readSetting.keepScreenAwakeWhenReading.isTrue) {
      WakelockPlus.enable();
    }

    if (GetPlatform.isMobile && readSetting.enableCustomReadBrightness.isTrue) {
      applyCurrentBrightness();
    }
    enableCustomBrightnessListener = ever(readSetting.enableCustomReadBrightness, (_) {
      if (GetPlatform.isMobile && readSetting.enableCustomReadBrightness.isTrue) {
        applyCurrentBrightness();
      } else {
        resetBrightness();
      }
    });
    customBrightnessListener = ever(readSetting.customBrightness, (_) {
      applyCurrentBrightness();
    });

    preloadListener = everAll(
      [readSetting.preloadPageCountLocal, readSetting.preloadPageCount, readSetting.preloadDistanceLocal, readSetting.preloadDistance],
      (_) => updateSafely([layoutId]),
    );

    inited = true;
    if (!delayInitCompleter.isCompleted) {
      delayInitCompleter.complete();
    }
  }

  @override
  void onClose() {
    super.onClose();

    // Cancel timers first
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    flushReadProgressTimer.cancel();

    // Dispose ALL Workers
    toggleTurnPageByVolumeKeyLister.dispose();
    toggleCurrentImmersiveModeLister.dispose();
    toggleDeviceOrientationLister.dispose();
    readDirectionLister.dispose();
    imageSpaceLister.dispose();
    displayFirstPageAloneListener.dispose();
    enableCustomBrightnessListener.dispose();
    customBrightnessListener.dispose();
    preloadListener.dispose();

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

    WakelockPlus.disable();

    // Dispose state last (clears lists, disposes focusNode)
    // IMPORTANT: Only clears lists that ReadPageState owns, not shared references
    state.dispose();
  }

  void beginToParseImageHref(int index) {
    if (state.parseImageHrefsStates[index] == LoadingState.loading) {
      return;
    }

    state.parseImageHrefsStates[index] = LoadingState.loading;
    updateSafely(['$parseImageHrefsStateId::$index']);

    /// limit the rate of parsing to decrease the lagging of build
    executor.scheduleTask(normalPriority, () => parseImageHref(index));
  }

  Future<void> parseImageHref(int index) async {
    log.trace('Begin to load Thumbnail $index with page size: ${state.thumbnailsCountPerPage}');

    int requestPageIndex = index ~/ state.thumbnailsCountPerPage;

    DetailPageInfo detailPageInfo;
    try {
      detailPageInfo = await retry(
        () => ehRequest.requestDetailPage(
          galleryUrl: state.readPageInfo.galleryUrl!,
          thumbnailsPageIndex: requestPageIndex,
          parser: EHSpiderParser.detailPage2RangeAndThumbnails,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioException,
        onRetry: (e) => log.error('Get thumbnails error!', (e as DioException).errorMsg),
      );
    } on DioException catch (_) {
      state.parseImageHrefErrorMsg = 'parsePageFailed'.tr;
      state.parseImageHrefsStates[index] = LoadingState.error;
      update(['$parseImageHrefsStateId::$index']);
      return;
    } on EHSiteException catch (e) {
      state.parseImageHrefErrorMsg = e.message;
      state.parseImageHrefsStates[index] = LoadingState.error;
      update(['$parseImageHrefsStateId::$index']);
      return;
    }

    state.parseImageHrefsStates[index] = LoadingState.idle;

    /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
    /// For example, default setting is 40, but some gallerys' thumbnails has only high quality thumbnails, which results in 20.
    bool thumbnailsCountPerPageChanged = state.thumbnailsCountPerPage != detailPageInfo.thumbnailsCountPerPage;
    state.thumbnailsCountPerPage = detailPageInfo.thumbnailsCountPerPage;

    for (int i = detailPageInfo.imageNoFrom; i <= detailPageInfo.imageNoTo; i++) {
      state.thumbnails[i] = detailPageInfo.thumbnails[i - detailPageInfo.imageNoFrom];
    }

    /// If we changed profile setting in EH site and have cached in JHenTai, we need to remove the cache to get the latest page info before re-parsing
    if (state.thumbnails[index] == null) {
      log.download(
        'Parse image hrefs error, thumbnails count per page is not equal to default setting, parse again. Thumbnails count per page: ${detailPageInfo.thumbnailsCountPerPage}, changed: $thumbnailsCountPerPageChanged',
      );
      await ehRequest.removeCacheByGalleryUrlAndPage(state.readPageInfo.galleryUrl!, requestPageIndex);
      return beginToParseImageHref(index);
    }

    updateSafely(['$onlineImageId::$index']);
  }

  void beginToParseImageUrl(int index, bool reParse, {String? reloadKey}) {
    if (state.parseImageUrlStates[index] == LoadingState.loading) {
      return;
    }

    state.parseImageUrlStates[index] = LoadingState.loading;
    updateSafely(['$parseImageUrlStateId::$index']);

    executor.scheduleTask(normalPriority, () => parseImageUrl(index, reParse, reloadKey));
  }

  Future<void> parseImageUrl(int index, bool reParse, String? reloadKey) async {
    GalleryImage image;
    try {
      image = await retry(
        () => requestImage(index, reParse, reloadKey),
        maxAttempts: 3,
        retryIf: (e) => e is DioException,
        onRetry: (e) => log.error('Parse gallery image failed, index: ${index.toString()}', (e as DioException).errorMsg),
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
    state.parseImageUrlStates[index] = LoadingState.success;
    updateSafely(['$onlineImageId::$index']);
  }

  Future<GalleryImage> requestImage(int index, bool reParse, String? reloadKey) {
    return ehRequest.requestImagePage(
      state.thumbnails[index]!.replacedMPVHref(index + 1),
      reloadKey: reloadKey,
      parser: EHSpiderParser.imagePage2GalleryImage,
      useCacheIfAvailable: !reParse,
    );
  }

  Future<void> reloadImage(int index) async {
    String? reloadKey;
    if (state.images[index] != null) {
      reloadKey = state.images[index]!.reloadKey;
      clearDiskCachedImage(state.images[index]!.url);
    }
    state.images[index] = null;
    beginToParseImageUrl(index, true, reloadKey: reloadKey);
    updateSafely(['$onlineImageId::$index']);
  }

  void listen2VolumeKeys() {
    volumeService.listen((VolumeEventType type) {
      if (type == VolumeEventType.volumeUp) {
        layoutLogic.toPrev();
      } else if (type == VolumeEventType.volumeDown) {
        layoutLogic.toNext();
      }
    });
    volumeService.setInterceptVolumeEvent(readSetting.enablePageTurnByVolumeKeys.value);
  }

  void restoreVolumeListener() {
    volumeService.cancelListen();
    volumeService.setInterceptVolumeEvent(false);
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
      ScreenBrightness().setScreenBrightness(readSetting.customBrightness.value.toDouble() / 100);
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
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    if (readSetting.deviceDirection.value == DeviceDirection.portrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    }
  }

  void restoreDeviceOrientation() {
    if (!GetPlatform.isMobile) {
      return;
    }

    SystemChrome.setPreferredOrientations([]);
  }

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
    if (lastThumbnailIndex == state.readPageInfo.pageCount - 1 && targetImageIndex > firstThumbnailIndex) {
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
    SuperResolutionType type = state.readPageInfo.mode == ReadMode.downloaded ? SuperResolutionType.gallery : SuperResolutionType.archive;
    SuperResolutionInfo? superResolutionInfo = superResolutionService.get(gid, type);

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
    return filterAndSortItems(state.thumbnailPositionsListener.itemPositions.value);
  }

  /// for some reason like slow loading of some image, [ItemPositions] may be not in index order, and even some of
  /// them are not in viewport
  List<ItemPosition> filterAndSortItems(Iterable<ItemPosition> positions) {
    positions = positions.where((item) => !(item.itemTrailingEdge < 0 || item.itemLeadingEdge > 1)).toList();
    (positions as List<ItemPosition>).sort((a, b) => a.index - b.index);
    return positions;
  }

  void recordReadProgress(int index) {
    state.readPageInfo.currentImageIndex = index;
    update([sliderId, pageNoId, thumbnailNoId]);
  }

  Future<void> _flushReadProgress() async {
    readProgressService.updateReadProgress(
      state.readPageInfo.readProgressRecordStorageKey,
      state.readPageInfo.currentImageIndex,
    );
  }

  void clearImageContainerSized() {
    state.imageContainerSizes = List.generate(state.readPageInfo.pageCount, (_) => null);
  }
}
