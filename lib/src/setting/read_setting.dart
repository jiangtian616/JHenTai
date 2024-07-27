import 'dart:convert';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

ReadSetting readSetting = ReadSetting();

class ReadSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxBool enableImmersiveMode = true.obs;
  RxBool keepScreenAwakeWhenReading = true.obs;
  RxBool enableCustomReadBrightness = false.obs;
  RxInt customBrightness = 50.obs;
  RxInt imageSpace = 6.obs;
  RxBool showThumbnails = true.obs;
  RxBool showScrollBar = true.obs;
  RxBool showStatusInfo = true.obs;
  RxBool enablePageTurnByVolumeKeys = true.obs;
  RxBool enablePageTurnAnime = true.obs;
  RxBool enableDoubleTapToScaleUp = false.obs;
  RxBool enableTapDragToScaleUp = false.obs;
  RxBool enableBottomMenu = false.obs;
  Rx<DeviceDirection> deviceDirection = DeviceDirection.followSystem.obs;
  Rx<ReadDirection> readDirection = GetPlatform.isMobile ? ReadDirection.top2bottomList.obs : ReadDirection.left2rightList.obs;
  RxBool notchOptimization = false.obs;
  RxInt imageRegionWidthRatio = 100.obs;
  RxInt gestureRegionWidthRatio = 60.obs;
  RxBool useThirdPartyViewer = false.obs;
  RxnString thirdPartyViewerPath = RxnString();
  RxDouble autoModeInterval = 2.0.obs;
  Rx<AutoModeStyle> autoModeStyle = AutoModeStyle.turnPage.obs;
  Rx<TurnPageMode> turnPageMode = TurnPageMode.adaptive.obs;
  RxInt preloadDistance = 1.obs;
  RxInt preloadDistanceLocal = GetPlatform.isIOS ? 3.obs : 8.obs;
  RxInt preloadPageCount = 1.obs;
  RxInt preloadPageCountLocal = 3.obs;
  RxBool displayFirstPageAlone = true.obs;
  RxBool reverseTurnPageDirection = false.obs;
  RxBool disablePageTurningOnTap = false.obs;
  RxBool enableMaxImageKilobyte =
      (GetPlatform.isDesktop || PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600)
          ? false.obs
          : true.obs;
  RxInt maxImageKilobyte = (1024 * 5).obs;

  bool get isInListReadDirection =>
      readDirection.value == ReadDirection.top2bottomList ||
      readDirection.value == ReadDirection.left2rightList ||
      readDirection.value == ReadDirection.right2leftList;

  bool get isInHorizontalReadDirection =>
      readDirection.value == ReadDirection.left2rightSinglePage ||
      readDirection.value == ReadDirection.right2leftSinglePage ||
      readDirection.value == ReadDirection.left2rightSinglePageFitWidth ||
      readDirection.value == ReadDirection.right2leftSinglePageFitWidth ||
      readDirection.value == ReadDirection.left2rightDoubleColumn ||
      readDirection.value == ReadDirection.right2leftDoubleColumn ||
      readDirection.value == ReadDirection.left2rightList ||
      readDirection.value == ReadDirection.right2leftList;

  bool get isInSinglePageReadDirection =>
      readDirection.value == ReadDirection.left2rightSinglePage ||
      readDirection.value == ReadDirection.right2leftSinglePage ||
      readDirection.value == ReadDirection.left2rightSinglePageFitWidth ||
      readDirection.value == ReadDirection.right2leftSinglePageFitWidth;

  bool get isInFitWidthReadDirection =>
      readDirection.value == ReadDirection.left2rightSinglePageFitWidth || readDirection.value == ReadDirection.right2leftSinglePageFitWidth;

  bool get isInDoubleColumnReadDirection =>
      readDirection.value == ReadDirection.left2rightDoubleColumn || readDirection.value == ReadDirection.right2leftDoubleColumn;

  bool get isInRight2LeftDirection =>
      readDirection.value == ReadDirection.right2leftSinglePage ||
      readDirection.value == ReadDirection.right2leftSinglePageFitWidth ||
      readDirection.value == ReadDirection.right2leftDoubleColumn ||
      readDirection.value == ReadDirection.right2leftList;

  @override
  ConfigEnum get configEnum => ConfigEnum.readSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    enableImmersiveMode.value = map['enableImmersiveMode'];
    keepScreenAwakeWhenReading.value = map['keepScreenAwakeWhenReading'] ?? keepScreenAwakeWhenReading.value;
    enableCustomReadBrightness.value = map['enableCustomReadBrightness'] ?? enableCustomReadBrightness.value;
    customBrightness.value = map['customBrightness'] ?? customBrightness.value;
    imageSpace.value = map['imageSpace'] ?? imageSpace.value;
    showThumbnails.value = map['showThumbnails'] ?? showThumbnails.value;
    showScrollBar.value = map['showScrollBar'] ?? showScrollBar.value;
    showStatusInfo.value = map['showStatusInfo'] ?? showStatusInfo.value;
    enablePageTurnByVolumeKeys.value = map['enablePageTurnByVolumeKeys'] ?? enablePageTurnByVolumeKeys.value;
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    enableDoubleTapToScaleUp.value = map['enableDoubleTapToScaleUp'] ?? enableDoubleTapToScaleUp.value;
    enableTapDragToScaleUp.value = map['enableTapDragToScaleUp'] ?? enableTapDragToScaleUp.value;
    enableBottomMenu.value = map['enableBottomMenu'] ?? enableBottomMenu.value;
    autoModeInterval.value = map['autoModeInterval'] ?? autoModeInterval.value;
    autoModeStyle.value = AutoModeStyle.values[map['autoModeStyle'] ?? AutoModeStyle.scroll.index];
    deviceDirection.value = DeviceDirection.values[map['deviceDirection'] ?? DeviceDirection.followSystem.index];
    readDirection.value = ReadDirection.values[map['readDirection']];
    notchOptimization.value = map['notchOptimization'] ?? notchOptimization.value;
    imageRegionWidthRatio.value = map['imageRegionWidthRatio'] ?? imageRegionWidthRatio.value;
    gestureRegionWidthRatio.value = map['gestureRegionWidthRatio'] ?? gestureRegionWidthRatio.value;
    useThirdPartyViewer.value = map['useThirdPartyViewer'] ?? useThirdPartyViewer.value;
    thirdPartyViewerPath.value = map['thirdPartyViewerPath'];
    turnPageMode.value = TurnPageMode.values[map['turnPageMode']];
    preloadDistance.value = map['preloadDistance'];
    preloadDistanceLocal.value = map['preloadDistanceLocal'] ?? preloadDistanceLocal.value;
    preloadPageCount.value = map['preloadPageCount'];
    preloadPageCountLocal.value = map['preloadPageCountLocal'] ?? preloadPageCountLocal.value;
    displayFirstPageAlone.value = map['displayFirstPageAlone'] ?? displayFirstPageAlone.value;
    reverseTurnPageDirection.value = map['reverseTurnPageDirection'] ?? reverseTurnPageDirection.value;
    disablePageTurningOnTap.value = map['disablePageTurningOnTap'] ?? disablePageTurningOnTap.value;
    enableMaxImageKilobyte.value = map['enableMaxImageKilobyte'] ?? enableMaxImageKilobyte.value;
    maxImageKilobyte.value = map['maxImageKilobyte'] ?? maxImageKilobyte.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'enableImmersiveMode': enableImmersiveMode.value,
      'keepScreenAwakeWhenReading': keepScreenAwakeWhenReading.value,
      'enableCustomReadBrightness': enableCustomReadBrightness.value,
      'customBrightness': customBrightness.value,
      'imageSpace': imageSpace.value,
      'showThumbnails': showThumbnails.value,
      'showScrollBar': showScrollBar.value,
      'showStatusInfo': showStatusInfo.value,
      'enablePageTurnByVolumeKeys': enablePageTurnByVolumeKeys.value,
      'enablePageTurnAnime': enablePageTurnAnime.value,
      'enableDoubleTapToScaleUp': enableDoubleTapToScaleUp.value,
      'enableTapDragToScaleUp': enableTapDragToScaleUp.value,
      'enableBottomMenu': enableBottomMenu.value,
      'autoModeInterval': autoModeInterval.value,
      'autoModeStyle': autoModeStyle.value.index,
      'deviceDirection': deviceDirection.value.index,
      'readDirection': readDirection.value.index,
      'notchOptimization': notchOptimization.value,
      'imageRegionWidthRatio': imageRegionWidthRatio.value,
      'gestureRegionWidthRatio': gestureRegionWidthRatio.value,
      'useThirdPartyViewer': useThirdPartyViewer.value,
      'thirdPartyViewerPath': thirdPartyViewerPath.value,
      'turnPageMode': turnPageMode.value.index,
      'preloadDistance': preloadDistance.value,
      'preloadDistanceLocal': preloadDistanceLocal.value,
      'preloadPageCount': preloadPageCount.value,
      'preloadPageCountLocal': preloadPageCountLocal.value,
      'displayFirstPageAlone': displayFirstPageAlone.value,
      'reverseTurnPageDirection': reverseTurnPageDirection.value,
      'disablePageTurningOnTap': disablePageTurningOnTap.value,
      'enableMaxImageKilobyte': enableMaxImageKilobyte.value,
      'maxImageKilobyte': maxImageKilobyte.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveEnableImmersiveMode(bool value) async {
    log.debug('saveEnableImmersiveMode:$value');
    enableImmersiveMode.value = value;
    await save();
  }

  Future<void> saveKeepScreenAwakeWhenReading(bool value) async {
    log.debug('saveKeepScreenAwakeWhenReading:$value');
    keepScreenAwakeWhenReading.value = value;
    await save();
  }

  Future<void> saveEnableCustomReadBrightness(bool value) async {
    log.debug('saveEnableCustomReadBrightness:$value');
    enableCustomReadBrightness.value = value;
    await save();
  }

  Future<void> saveCustomBrightness(int value) async {
    log.debug('saveCustomBrightness:$value');
    customBrightness.value = value;
    await save();
  }

  Future<void> saveImageSpace(int value) async {
    log.debug('saveImageSpace:$value');
    imageSpace.value = value;
    await save();
  }

  Future<void> saveShowThumbnails(bool value) async {
    log.debug('saveShowThumbnails:$value');
    showThumbnails.value = value;
    await save();
  }

  Future<void> saveShowScrollBar(bool value) async {
    log.debug('saveShowScrollBar:$value');
    showScrollBar.value = value;
    await save();
  }

  Future<void> saveShowStatusInfo(bool value) async {
    log.debug('saveShowStatusInfo:$value');
    showStatusInfo.value = value;
    await save();
  }

  Future<void> saveAutoModeInterval(double value) async {
    log.debug('saveAutoModeInterval:$value');
    autoModeInterval.value = value;
    await save();
  }

  Future<void> saveAutoModeStyle(AutoModeStyle value) async {
    log.debug('saveAutoModeStyle:${value.name}');
    autoModeStyle.value = value;
    await save();
  }

  Future<void> saveDeviceDirection(DeviceDirection value) async {
    log.debug('saveDeviceDirection:${value.name}');
    deviceDirection.value = value;
    await save();
  }

  Future<void> saveReadDirection(ReadDirection value) async {
    log.debug('saveReadDirection:${value.name}');
    readDirection.value = value;
    await save();
  }

  Future<void> saveNotchOptimization(bool value) async {
    log.debug('saveNotchOptimization:$value');
    notchOptimization.value = value;
    await save();
  }

  Future<void> saveImageRegionWidthRatio(int value) async {
    log.debug('saveImageRegionWidthRatio:$value');
    imageRegionWidthRatio.value = value;
    await save();
  }

  Future<void> saveGestureRegionWidthRatio(int value) async {
    log.debug('saveGestureRegionWidthRatio:$value');
    gestureRegionWidthRatio.value = value;
    await save();
  }

  Future<void> saveUseThirdPartyViewer(bool value) async {
    log.debug('saveUseThirdPartyViewer:$value');
    useThirdPartyViewer.value = value;
    await save();
  }

  Future<void> saveThirdPartyViewerPath(String? value) async {
    log.debug('saveThirdPartyViewerPath:$value');
    thirdPartyViewerPath.value = value;
    await save();
  }

  Future<void> saveEnablePageTurnByVolumeKeys(bool value) async {
    log.debug('saveEnablePageTurnByVolumeKeys:$value');
    enablePageTurnByVolumeKeys.value = value;
    await save();
  }

  Future<void> saveEnablePageTurnAnime(bool value) async {
    log.debug('saveEnablePageTurnAnime:$value');
    enablePageTurnAnime.value = value;
    await save();
  }

  Future<void> saveEnableDoubleTapToScaleUp(bool value) async {
    log.debug('saveEnableDoubleTapToScaleUp:$value');
    enableDoubleTapToScaleUp.value = value;
    await save();
  }

  Future<void> saveEnableTapDragToScaleUp(bool value) async {
    log.debug('saveEnableTapDragToScaleUp:$value');
    enableTapDragToScaleUp.value = value;
    await save();
  }

  Future<void> saveEnableBottomMenu(bool value) async {
    log.debug('saveEnableBottomMenu:$value');
    enableBottomMenu.value = value;
    await save();
  }

  Future<void> saveTurnPageMode(TurnPageMode value) async {
    log.debug('saveTurnPageMode:${value.name}');
    turnPageMode.value = value;
    await save();
  }

  Future<void> savePreloadDistance(int value) async {
    log.debug('savePreloadDistance:$value');
    preloadDistance.value = value;
    await save();
  }

  Future<void> savePreloadDistanceLocal(int value) async {
    log.debug('savePreloadDistanceLocal:$value');
    preloadDistanceLocal.value = value;
    await save();
  }

  Future<void> savePreloadPageCount(int value) async {
    log.debug('savePreloadPageCount:$value');
    preloadPageCount.value = value;
    await save();
  }

  Future<void> savePreloadPageCountLocal(int value) async {
    log.debug('savePreloadPageCountLocal:$value');
    preloadPageCountLocal.value = value;
    await save();
  }

  Future<void> saveDisplayFirstPageAlone(bool value) async {
    log.debug('saveDisplayFirstPageAlone:$value');
    displayFirstPageAlone.value = value;
    await save();
  }

  Future<void> saveReverseTurnPageDirection(bool value) async {
    log.debug('saveReverseTurnPageDirection:$value');
    reverseTurnPageDirection.value = value;
    await save();
  }

  Future<void> saveDisablePageTurningOnTap(bool value) async {
    log.debug('saveDisablePageTurningOnTap:$value');
    disablePageTurningOnTap.value = value;
    await save();
  }

  Future<void> saveEnableMaxImageKilobyte(bool value) async {
    log.debug('saveEnableMaxImageKilobyte:$value');
    enableMaxImageKilobyte.value = value;
    await save();
  }

  Future<void> saveMaxImageKilobyte(int value) async {
    log.debug('saveMaxImageKilobyte:$value');
    maxImageKilobyte.value = value;
    await save();
  }
}

enum DeviceDirection { followSystem, landscape, portrait }

enum ReadDirection {
  top2bottomList,
  left2rightSinglePage,
  left2rightSinglePageFitWidth,
  left2rightDoubleColumn,
  left2rightList,
  right2leftSinglePage,
  right2leftSinglePageFitWidth,
  right2leftDoubleColumn,
  right2leftList,
}

enum TurnPageMode {
  image,
  screen,

  /// if one image covers the whole screen => screen
  /// else => image
  adaptive,
}

enum AutoModeStyle {
  scroll,
  turnPage,
}
