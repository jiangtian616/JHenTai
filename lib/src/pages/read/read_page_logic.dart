import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/tap_zone_config.dart';
import 'package:jhentai/src/pages/read/layout/base/base_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/vertical_list/vertical_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
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
import '../../routes/routes.dart';
import '../../service/local_config_service.dart';
import '../../service/log.dart';
import '../../service/gallery_download/gallery_images_retainer.dart';
import '../../service/read_progress_service.dart';
import '../../setting/preference_setting.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/route_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/auto_mode_interval_dialog.dart';
import '../../widget/eh_image.dart';
import '../../widget/loading_state_indicator.dart';
import '../home_page.dart';
import '../setting/read/setting_read_page.dart';
import '../setting/read/tap_zone/setting_tap_zone_page.dart';
import '../setting/keyboard_shortcuts/setting_keyboard_shortcuts_page.dart';

class ReadPageLogic extends GetxController with WidgetsBindingObserver, GalleryImagesRetainer {
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
  final String tapZoneId = 'tapZoneId';
  final String guideOverlayId = 'guideOverlayId';
  final String switchGalleryHintId = 'switchGalleryHintId';

  ReadPageState state;

  /// [readPageInfo] is null if read page is opened by route, see [ReadPage]
  ReadPageLogic({ReadPageInfo? readPageInfo}) : state = ReadPageState(readPageInfo ?? Get.arguments);

  /// Replace the gallery in read page, set by [ReadPage]
  void Function(ReadPageInfo readPageInfo)? switchGalleryHandler;

  /// This read page is being replaced by the one of another gallery, see [switchGalleryHandler]
  bool isSwitchingGallery = false;

  bool _isLoadingAdjacentGallery = false;

  Timer? _switchGalleryHintTimer;
  DateTime? _lastTurnPageBeyondBoundaryTime;

  /// Drag distance beyond the first or last page in the gesture going on
  double _dragOverscroll = 0;

  BaseLayoutLogic get layoutLogic => effectiveReadDirection == ReadDirection.top2bottomList
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
  late Worker toggleDeviceOrientationLister;
  late Worker readDirectionLister;
  late Worker imageSpaceLister;
  late Worker displayFirstPageAloneListener;
  late Worker enableCustomBrightnessListener;
  late Worker customBrightnessListener;
  late Worker preloadListener;
  late Worker enableBottomMenuListener;
  late Worker enablePageTurnAnimeListener;
  late Worker orientationSpecificReadDirectionLister;
  late Worker portraitReadDirectionLister;
  late Worker landscapeReadDirectionLister;
  late Worker portraitImageRegionWidthRatioLister;
  late Worker landscapeImageRegionWidthRatioLister;
  late Worker portraitDisplayFirstPageAloneListener;
  late Worker landscapeDisplayFirstPageAloneListener;
  late Worker autoDetectWebtoonListener;
  late Worker tapZoneConfigListener;

  /// Tracks the last known portrait state for orientation-specific read direction
  bool? _lastIsPortrait;

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

    /// Retain the gallery's image list for the lifetime of the read page.
    /// The caller (goToReadPage) already ensured [ensureImagesLoaded] so the
    /// list is resident when [ReadPageState] was constructed; this retain
    /// keeps it resident even if the download completes mid-read (eviction
    /// is deferred to our onClose). Online / archive / local modes have no
    /// service-side list to retain — skip.
    if (state.readPageInfo.mode == ReadMode.downloaded && state.readPageInfo.gid != null) {
      retainGalleryImages(state.readPageInfo.gid!);
    }

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
    toggleTurnPageByVolumeKeyLister = ever(readSetting.enablePageTurnByVolumeKeys, (_) => listen2VolumeKeys());

    /// Listen to immersive mode change
    toggleCurrentImmersiveModeLister = ever(readSetting.enableImmersiveMode, (_) => applyCurrentImmersiveMode());

    /// Listen to device orientation change
    toggleDeviceOrientationLister = ever(readSetting.deviceDirection, (_) => updateDeviceOrientation());

    /// Listen to read direction change
    readDirectionLister = ever(readSetting.readDirection, (_) => onEffectiveSettingChanged());

    imageSpaceLister = ever(readSetting.imageSpace, (_) {
      updateSafely([layoutId]);
    });

    displayFirstPageAloneListener = ever(readSetting.displayFirstPageAlone, (_) => _syncDisplayFirstPageAloneToState());
    portraitDisplayFirstPageAloneListener = ever(readSetting.portraitDisplayFirstPageAlone, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && isPortrait) {
        _syncDisplayFirstPageAloneToState();
      }
    });
    landscapeDisplayFirstPageAloneListener = ever(readSetting.landscapeDisplayFirstPageAlone, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && !isPortrait) {
        _syncDisplayFirstPageAloneToState();
      }
    });

    /// Listen to orientation-specific settings changes for rebuild
    orientationSpecificReadDirectionLister = ever(readSetting.enableOrientationSpecificReadDirection, (_) => onEffectiveSettingChanged());
    portraitReadDirectionLister = ever(readSetting.portraitReadDirection, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && isPortrait) {
        onEffectiveSettingChanged();
      }
    });
    landscapeReadDirectionLister = ever(readSetting.landscapeReadDirection, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && !isPortrait) {
        onEffectiveSettingChanged();
      }
    });
    autoDetectWebtoonListener = ever(readSetting.autoDetectWebtoon, (_) => onEffectiveSettingChanged());
    portraitImageRegionWidthRatioLister = ever(readSetting.portraitImageRegionWidthRatio, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && isPortrait) {
        updateSafely([layoutId]);
      }
    });
    landscapeImageRegionWidthRatioLister = ever(readSetting.landscapeImageRegionWidthRatio, (_) {
      if (readSetting.enableOrientationSpecificReadDirection.isTrue && !isPortrait) {
        updateSafely([layoutId]);
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

    enableBottomMenuListener = ever(readSetting.enableBottomMenu, (_) {
      updateSafely([topMenuId]);
    });

    /// rebuild layout so that swipe page turn follows the switches immediately
    enablePageTurnAnimeListener = everAll(
      [readSetting.enablePageTurnAnime, readSetting.enableSwipePageTurnAnime],
      (_) => updateSafely([layoutId]),
    );

    preloadListener = everAll(
      [readSetting.preloadPageCountLocal, readSetting.preloadPageCount, readSetting.preloadDistanceLocal, readSetting.preloadDistance],
      (_) => updateSafely([layoutId]),
    );

    _syncDisplayFirstPageAloneToState();

    tapZoneConfigListener = ever(readSetting.tapZoneConfigJson, (_) => updateSafely([tapZoneId]));

    _maybeShowTapZoneGuide();

    inited = true;
    if (!delayInitCompleter.isCompleted) {
      delayInitCompleter.complete();
    }
  }

  Future<void> _maybeShowTapZoneGuide() async {
    String? shown = await localConfigService.read(configKey: ConfigEnum.tapZoneGuideShown);
    if (shown != null) {
      return;
    }
    state.showTapZoneGuide = true;
    updateSafely([guideOverlayId]);
  }

  void dismissTapZoneGuide() {
    state.showTapZoneGuide = false;
    update([guideOverlayId]);
    localConfigService.write(configKey: ConfigEnum.tapZoneGuideShown, value: 'true');
  }

  @override
  void onClose() {
    super.onClose();

    WidgetsBinding.instance.removeObserver(this);

    state.focusNode.dispose();
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    toggleTurnPageByVolumeKeyLister.dispose();
    toggleCurrentImmersiveModeLister.dispose();
    readDirectionLister.dispose();
    imageSpaceLister.dispose();
    flushReadProgressTimer.cancel();
    displayFirstPageAloneListener.dispose();
    enableCustomBrightnessListener.dispose();
    customBrightnessListener.dispose();
    preloadListener.dispose();
    enableBottomMenuListener.dispose();
    enablePageTurnAnimeListener.dispose();
    orientationSpecificReadDirectionLister.dispose();
    portraitReadDirectionLister.dispose();
    landscapeReadDirectionLister.dispose();
    portraitImageRegionWidthRatioLister.dispose();
    landscapeImageRegionWidthRatioLister.dispose();
    portraitDisplayFirstPageAloneListener.dispose();
    landscapeDisplayFirstPageAloneListener.dispose();
    autoDetectWebtoonListener.dispose();
    tapZoneConfigListener.dispose();
    _switchGalleryHintTimer?.cancel();

    restoreVolumeListener();

    _flushReadProgress();

    /// keep them when switching to another gallery, otherwise system bars, screen orientation and brightness would flicker
    if (!isSwitchingGallery) {
      restoreImmersiveMode();

      restoreDeviceOrientation();

      if (readSetting.enableCustomReadBrightness.isTrue) {
        resetBrightness();
      }

      WakelockPlus.disable();
    }

    /// Gallery image retain released by [GalleryImagesRetainer.onClose]
    /// (super.onClose below). If the gallery is fully downloaded and no
    /// other consumer holds a retain, the list is evicted there.

    Get.delete<VerticalListLayoutLogic>(force: true);
    Get.delete<HorizontalListLayoutLogic>(force: true);
    Get.delete<HorizontalPageLayoutLogic>(force: true);
    Get.delete<HorizontalDoubleColumnLayoutLogic>(force: true);

    executor.close();

    /// Unpause + forget every animation gate this page created so a codec
    /// parked on a gate is not frozen forever after the page is torn down.
    EHImageAnimationGateRegistry.clear();
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
    /// For example, default setting is 40, but some galleries' thumbnails has only high quality thumbnails, which results in 20.
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

    final Size size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final bool isPortrait = size.height >= size.width;

    if (_lastIsPortrait == null) {
      _lastIsPortrait = isPortrait;
      return;
    }

    if (_lastIsPortrait == isPortrait) {
      return;
    }

    _lastIsPortrait = isPortrait;

    final ReadDirection targetDirection = isPortrait ? readSetting.portraitReadDirection.value : readSetting.landscapeReadDirection.value;
    final String directionName = targetDirection.name.tr;
    final String orientationKey = isPortrait ? 'portrait' : 'landscape';
    toast('${'autoSwitchedReadDirection'.tr}: $directionName (${orientationKey.tr})');

    onEffectiveSettingChanged();
  }

  void onEffectiveSettingChanged() {
    clearImageContainerSized();
    state.readPageInfo.initialIndex = state.readPageInfo.currentImageIndex;
    _syncDisplayFirstPageAloneToState();
    updateSafely([layoutId]);
  }

  void _syncDisplayFirstPageAloneToState() {
    final bool effective = effectiveDisplayFirstPageAlone;
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
    final Size size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    return size.height >= size.width;
  }

  ReadDirection get effectiveReadDirection {
    if (readSetting.autoDetectWebtoon.isTrue && state.readPageInfo.readDirection != null) {
      return state.readPageInfo.readDirection!;
    }
    if (readSetting.enableOrientationSpecificReadDirection.isFalse || !GetPlatform.isMobile) {
      return readSetting.readDirection.value;
    }
    if (isPortrait) {
      return readSetting.portraitReadDirection.value;
    }
    return readSetting.landscapeReadDirection.value;
  }

  void saveReadDirection(ReadDirection value) {
    state.readPageInfo.readDirection = null;

    if (readSetting.enableOrientationSpecificReadDirection.isTrue && GetPlatform.isMobile) {
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
    if (!GetPlatform.isMobile || readSetting.enableOrientationSpecificReadDirection.isFalse) {
      return readSetting.imageRegionWidthRatio.value;
    }
    return isPortrait ? readSetting.portraitImageRegionWidthRatio.value : readSetting.landscapeImageRegionWidthRatio.value;
  }

  bool get effectiveDisplayFirstPageAlone {
    if (!GetPlatform.isMobile || readSetting.enableOrientationSpecificReadDirection.isFalse) {
      return readSetting.displayFirstPageAlone.value;
    }
    return isPortrait ? readSetting.portraitDisplayFirstPageAlone.value : readSetting.landscapeDisplayFirstPageAlone.value;
  }

  bool get isInListReadDirection => ReadSetting.isListDirection(effectiveReadDirection);

  bool get isInDoubleColumnReadDirection => ReadSetting.isDoubleColumnDirection(effectiveReadDirection);

  bool get isInSinglePageReadDirection => ReadSetting.isSinglePageDirection(effectiveReadDirection);

  bool get isInFitWidthReadDirection => ReadSetting.isFitWidthDirection(effectiveReadDirection);

  bool get isInRight2LeftDirection => ReadSetting.isRight2LeftDirection(effectiveReadDirection);

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

  void handleTapZone(int index) {
    if (!inited) {
      return;
    }

    if (state.isScrolling) {
      return;
    }

    switch (readSetting.tapZoneConfig.actions[index]) {
      case TapZoneAction.none:
        break;
      case TapZoneAction.toggleMenu:
        toggleMenu();
      case TapZoneAction.prevPage:
        toPrev();
      case TapZoneAction.nextPage:
        toNext();
      case TapZoneAction.flipLeft:
        toLeft();
      case TapZoneAction.flipRight:
        toRight();
    }
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

  bool get canSwitchGallery =>
      readSetting.enableAutoSwitchGallery.isTrue && state.readPageInfo.adjacentGalleryFinder != null && switchGalleryHandler != null;

  /// User tries to turn to the page before the first one or after the last one, e.g. by tapping, keys or mouse wheel.
  ///
  /// The first try only shows which gallery is the previous or next one, and trying again switches to it, so that users won't leave
  /// current gallery by accident.
  void handleTurnPageBeyondBoundary(bool next) {
    if (!canSwitchGallery || _isLoadingAdjacentGallery || isSwitchingGallery) {
      return;
    }

    /// Mouse wheel and long pressed keys trigger this continuously, only a try after a pause is regarded as a confirmation
    DateTime now = DateTime.now();
    bool isNewTry = _lastTurnPageBeyondBoundaryTime == null || now.difference(_lastTurnPageBeyondBoundaryTime!) > const Duration(milliseconds: 400);
    _lastTurnPageBeyondBoundaryTime = now;

    SwitchGalleryHint? hint = state.switchGalleryHint;
    if (hint != null && hint.next == next) {
      if (isNewTry && hint.gallery != null) {
        _switchGallery(hint.gallery!);
      } else {
        _hideSwitchGalleryHintLater();
      }
      return;
    }

    state.switchGalleryHint = SwitchGalleryHint(next: next, gallery: state.readPageInfo.adjacentGalleryFinder!.call(next));
    updateSafely([switchGalleryHintId]);
    _hideSwitchGalleryHintLater();
  }

  /// Dragging beyond the first or last page works the same as [handleTurnPageBeyondBoundary]
  void handleScrollNotification(ScrollNotification notification) {
    if (!canSwitchGallery) {
      return;
    }

    /// ignore scrollables in the other axis, e.g. the one of a single image in fit width mode
    Axis axis = effectiveReadDirection == ReadDirection.top2bottomList ? Axis.vertical : Axis.horizontal;
    if (notification.metrics.axis != axis) {
      return;
    }

    if (notification is ScrollStartNotification) {
      _dragOverscroll = 0;
    } else if (notification is OverscrollNotification && notification.dragDetails != null) {
      _dragOverscroll += notification.overscroll;
    } else if (notification is ScrollEndNotification) {
      double dragOverscroll = _dragOverscroll;
      _dragOverscroll = 0;
      if (dragOverscroll.abs() >= 40) {
        handleTurnPageBeyondBoundary(dragOverscroll > 0);
      }
    }
  }

  void hideSwitchGalleryHint() {
    _switchGalleryHintTimer?.cancel();
    if (state.switchGalleryHint != null) {
      state.switchGalleryHint = null;
      updateSafely([switchGalleryHintId]);
    }
  }

  void _hideSwitchGalleryHintLater() {
    _switchGalleryHintTimer?.cancel();
    _switchGalleryHintTimer = Timer(const Duration(seconds: 4), hideSwitchGalleryHint);
  }

  Future<void> _switchGallery(AdjacentGallery gallery) async {
    _isLoadingAdjacentGallery = true;

    ReadPageInfo? readPageInfo;
    try {
      readPageInfo = await gallery.loadReadPageInfo();
    } catch (e, s) {
      log.error('Load adjacent gallery failed: ${gallery.title}', e, s);
    }

    _isLoadingAdjacentGallery = false;

    /// read page is closed while loading
    if (isClosed) {
      return;
    }

    if (readPageInfo == null || readPageInfo.pageCount <= 0) {
      hideSwitchGalleryHint();
      toast('switchGalleryFailed'.tr);
      return;
    }

    log.info('Switch gallery in read page: ${state.readPageInfo.galleryTitle} -> ${readPageInfo.galleryTitle}');

    if (state.autoMode) {
      closeAutoMode();
    }
    isSwitchingGallery = true;
    switchGalleryHandler!.call(readPageInfo);
  }

  void recordReadProgress(int index) {
    /// left the first or last page
    if (state.switchGalleryHint != null && index != state.readPageInfo.currentImageIndex) {
      hideSwitchGalleryHint();
    }

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

  Future<void> openReadSetting(BuildContext context) async {
    if (styleSetting.isInDesktopLayout || styleSetting.isInTabletLayout) {
      await _showReadSettingDrawer(context);
    } else {
      await _pushReadSettingPage();
    }
  }

  Future<void> _pushReadSettingPage() async {
    restoreImmersiveMode();
    toRoute(Routes.settingRead, id: fullScreen)?.then((_) {
      applyCurrentImmersiveMode();
      state.focusNode.requestFocus();
    });
  }

  /// The drawer covers only part of read page, so keep immersive mode. Otherwise system bars show up during its animation,
  /// and the drawer and read page jitter because the safe area changes. Toggling immersive mode inside it still applies at once.
  Future<void> _showReadSettingDrawer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) {
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
            child: Material(
              elevation: 16,
              child: Navigator(
                key: const Key('readPageLogic'),
                initialRoute: '/',
                onGenerateRoute: (settings) {
                  final bool useCupertino = preferenceSetting.enableSwipeBackGesture.isTrue;
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
                  if (settings.name == '/tap_zone_style') {
                    return _buildDrawerRoute(
                      builder: (_) => const SettingTapZonePage(),
                      settings: settings,
                      useCupertino: useCupertino,
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
        );
      },
    );

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
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        ),
        settings: settings,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, __, ___) => builder(context),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      settings: settings,
    );
  }
}
