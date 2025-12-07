import 'dart:convert';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/ml_tts_service.dart';

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

  RxBool mlTtsEnable = false.obs;
  Rx<TextRecognitionScript> mlTtsScript = TextRecognitionScript.latin.obs;
  Rx<TtsDirection> mlTtsDirection = TtsDirection.defaultDirection.obs;
  RxnString mlTtsLanguage = RxnString('zh-CN');
  RxnString mlTtsEngine = RxnString();
  RxDouble mlTtsVolume = 0.5.obs;
  RxDouble mlTtsPitch = 1.0.obs;
  RxDouble mlTtsRate = 0.5.obs;
  RxnString mlTtsExclusionList = RxnString();
  RxnString mlTtsReplaceList = RxnString();
  RxInt mlTtsMinWordLimit = 3.obs;

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
  void applyBeanConfig(String configString) {
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
    mlTtsEnable.value = map['mlTtsEnable'] ?? mlTtsEnable.value;
    mlTtsScript.value = TextRecognitionScript.values[map['mlTtsScript'] ?? TextRecognitionScript.latin.index];
    mlTtsDirection.value = TtsDirection.values[map['mlTtsDirection'] ?? TtsDirection.defaultDirection.index];
    mlTtsLanguage.value = map['mlTtsLanguage'] ?? mlTtsLanguage.value;
    mlTtsEngine.value = map['mlTtsEngine'] ?? mlTtsEngine.value;
    mlTtsPitch.value = map['mlTtsPitch'] ?? mlTtsPitch.value;
    mlTtsVolume.value = map['mlTtsVolume'] ?? mlTtsVolume.value;
    mlTtsRate.value = map['mlTtsRate'] ?? mlTtsRate.value;
    mlTtsExclusionList.value = map['mlTtsExclusionList'] ?? mlTtsExclusionList.value;
    mlTtsReplaceList.value = map['mlTtsReplaceList'] ?? mlTtsReplaceList.value;
    mlTtsMinWordLimit.value = map['mlTtsMinWordLimit'] ?? mlTtsMinWordLimit.value;
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
      'mlTtsEnable': mlTtsEnable.value,
      'mlTtsScript': mlTtsScript.value.index,
      'mlTtsDirection': mlTtsDirection.value.index,
      'mlTtsEngine': mlTtsEngine.value,
      'mlTtsLanguage': mlTtsLanguage.value,
      'mlTtsRate': mlTtsRate.value,
      'mlTtsVolume': mlTtsVolume.value,
      'mlTtsPitch': mlTtsPitch.value,
      'mlTtsExclusionList': mlTtsExclusionList.value,
      'mlTtsReplaceList': mlTtsReplaceList.value,
      'mlTtsMinWordLimit': mlTtsMinWordLimit.value,
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
    await saveBeanConfig();
  }

  Future<void> saveKeepScreenAwakeWhenReading(bool value) async {
    log.debug('saveKeepScreenAwakeWhenReading:$value');
    keepScreenAwakeWhenReading.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableCustomReadBrightness(bool value) async {
    log.debug('saveEnableCustomReadBrightness:$value');
    enableCustomReadBrightness.value = value;
    await saveBeanConfig();
  }

  Future<void> saveCustomBrightness(int value) async {
    log.debug('saveCustomBrightness:$value');
    customBrightness.value = value;
    await saveBeanConfig();
  }

  Future<void> saveImageSpace(int value) async {
    log.debug('saveImageSpace:$value');
    imageSpace.value = value;
    await saveBeanConfig();
  }

  Future<void> saveShowThumbnails(bool value) async {
    log.debug('saveShowThumbnails:$value');
    showThumbnails.value = value;
    await saveBeanConfig();
  }

  Future<void> saveShowScrollBar(bool value) async {
    log.debug('saveShowScrollBar:$value');
    showScrollBar.value = value;
    await saveBeanConfig();
  }

  Future<void> saveShowStatusInfo(bool value) async {
    log.debug('saveShowStatusInfo:$value');
    showStatusInfo.value = value;
    await saveBeanConfig();
  }

  Future<void> saveAutoModeInterval(double value) async {
    log.debug('saveAutoModeInterval:$value');
    autoModeInterval.value = value;
    await saveBeanConfig();
  }

  Future<void> saveAutoModeStyle(AutoModeStyle value) async {
    log.debug('saveAutoModeStyle:${value.name}');
    autoModeStyle.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDeviceDirection(DeviceDirection value) async {
    log.debug('saveDeviceDirection:${value.name}');
    deviceDirection.value = value;
    await saveBeanConfig();
  }

  Future<void> saveReadDirection(ReadDirection value) async {
    log.debug('saveReadDirection:${value.name}');
    readDirection.value = value;
    await saveBeanConfig();
  }

  Future<void> saveNotchOptimization(bool value) async {
    log.debug('saveNotchOptimization:$value');
    notchOptimization.value = value;
    await saveBeanConfig();
  }

  Future<void> saveImageRegionWidthRatio(int value) async {
    log.debug('saveImageRegionWidthRatio:$value');
    imageRegionWidthRatio.value = value;
    await saveBeanConfig();
  }

  Future<void> saveGestureRegionWidthRatio(int value) async {
    log.debug('saveGestureRegionWidthRatio:$value');
    gestureRegionWidthRatio.value = value;
    await saveBeanConfig();
  }

  Future<void> saveUseThirdPartyViewer(bool value) async {
    log.debug('saveUseThirdPartyViewer:$value');
    useThirdPartyViewer.value = value;
    await saveBeanConfig();
  }

  Future<void> saveThirdPartyViewerPath(String? value) async {
    log.debug('saveThirdPartyViewerPath:$value');
    thirdPartyViewerPath.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsEnable(bool value) async {
    log.debug('saveMlTtsEnable:$value');
    mlTtsEnable.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsScript(TextRecognitionScript value) async {
    log.debug('saveMlTtsScript:${value.name}');
    mlTtsScript.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsDirection(TtsDirection value) async {
    log.debug('saveMlTtsDirection:${value.name}');
    mlTtsDirection.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsLanguage(String? value) async {
    log.debug('saveMlTtsLanguage:$value');
    mlTtsLanguage.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsEngine(String? value) async {
    log.debug('saveMlTtsEngine:$value');
    mlTtsEngine.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsPitch(double value) async {
    log.debug('saveMlTtsPitch:$value');
    mlTtsPitch.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsVolume(double value) async {
    log.debug('saveMlTtsVolume:$value');
    mlTtsVolume.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsRate(double value) async {
    log.debug('saveMlTtsRate:$value');
    mlTtsRate.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsExclusionList(String? value) async {
    log.debug('saveMlTtsExclusionList:$value');
    mlTtsExclusionList.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsReplaceList(String? value) async {
    log.debug('saveMlTtsReplaceList:$value');
    mlTtsReplaceList.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMlTtsMinWordLimit(int value) async {
    log.debug('saveMlTtsMinWordLimit:$value');
    mlTtsMinWordLimit.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnablePageTurnByVolumeKeys(bool value) async {
    log.debug('saveEnablePageTurnByVolumeKeys:$value');
    enablePageTurnByVolumeKeys.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnablePageTurnAnime(bool value) async {
    log.debug('saveEnablePageTurnAnime:$value');
    enablePageTurnAnime.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableDoubleTapToScaleUp(bool value) async {
    log.debug('saveEnableDoubleTapToScaleUp:$value');
    enableDoubleTapToScaleUp.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableTapDragToScaleUp(bool value) async {
    log.debug('saveEnableTapDragToScaleUp:$value');
    enableTapDragToScaleUp.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableBottomMenu(bool value) async {
    log.debug('saveEnableBottomMenu:$value');
    enableBottomMenu.value = value;
    await saveBeanConfig();
  }

  Future<void> saveTurnPageMode(TurnPageMode value) async {
    log.debug('saveTurnPageMode:${value.name}');
    turnPageMode.value = value;
    await saveBeanConfig();
  }

  Future<void> savePreloadDistance(int value) async {
    log.debug('savePreloadDistance:$value');
    preloadDistance.value = value;
    await saveBeanConfig();
  }

  Future<void> savePreloadDistanceLocal(int value) async {
    log.debug('savePreloadDistanceLocal:$value');
    preloadDistanceLocal.value = value;
    await saveBeanConfig();
  }

  Future<void> savePreloadPageCount(int value) async {
    log.debug('savePreloadPageCount:$value');
    preloadPageCount.value = value;
    await saveBeanConfig();
  }

  Future<void> savePreloadPageCountLocal(int value) async {
    log.debug('savePreloadPageCountLocal:$value');
    preloadPageCountLocal.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDisplayFirstPageAlone(bool value) async {
    log.debug('saveDisplayFirstPageAlone:$value');
    displayFirstPageAlone.value = value;
    await saveBeanConfig();
  }

  Future<void> saveReverseTurnPageDirection(bool value) async {
    log.debug('saveReverseTurnPageDirection:$value');
    reverseTurnPageDirection.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDisablePageTurningOnTap(bool value) async {
    log.debug('saveDisablePageTurningOnTap:$value');
    disablePageTurningOnTap.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableMaxImageKilobyte(bool value) async {
    log.debug('saveEnableMaxImageKilobyte:$value');
    enableMaxImageKilobyte.value = value;
    await saveBeanConfig();
  }

  Future<void> saveMaxImageKilobyte(int value) async {
    log.debug('saveMaxImageKilobyte:$value');
    maxImageKilobyte.value = value;
    await saveBeanConfig();
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
