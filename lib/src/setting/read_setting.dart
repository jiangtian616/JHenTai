import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

enum ReadDirection {
  top2bottom,
  left2right,
  right2left,
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

class ReadSetting {
  static RxBool enableImmersiveMode = true.obs;
  static RxBool showThumbnails = true.obs;
  static RxBool showStatusInfo = true.obs;
  static RxBool enablePageTurnAnime = true.obs;
  static RxBool enableDoubleTapToScaleUp = false.obs;
  static Rx<ReadDirection> readDirection = ReadDirection.top2bottom.obs;
  static RxBool useThirdPartyViewer = false.obs;
  static RxnString thirdPartyViewerPath = RxnString();
  static RxDouble autoModeInterval = 2.0.obs;
  static Rx<AutoModeStyle> autoModeStyle = AutoModeStyle.turnPage.obs;
  static Rx<TurnPageMode> turnPageMode = TurnPageMode.adaptive.obs;
  static RxInt preloadDistance = 1.obs;
  static RxInt preloadPageCount = 1.obs;
  static RxBool enableContinuousHorizontalScroll = false.obs;
  static RxBool enableAutoScaleUp = false.obs;
  static RxBool enableDoubleColumn = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('readSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init ReadSetting success', false);
    } else {
      Log.debug('init ReadSetting success: default', false);
    }
  }

  static saveEnableImmersiveMode(bool value) {
    Log.debug('saveEnableImmersiveMode:$value');
    enableImmersiveMode.value = value;
    _save();
  }

  static saveShowThumbnails(bool value) {
    Log.debug('saveShowThumbnails:$value');
    showThumbnails.value = value;
    _save();
  }

  static saveShowStatusInfo(bool value) {
    Log.debug('saveShowStatusInfo:$value');
    showStatusInfo.value = value;
    _save();
  }

  static saveAutoModeInterval(double value) {
    Log.debug('saveAutoModeInterval:$value');
    autoModeInterval.value = value;
    _save();
  }

  static saveAutoModeStyle(AutoModeStyle value) {
    Log.debug('saveAutoModeStyle:${value.name}');
    autoModeStyle.value = value;
    _save();
  }

  static saveReadDirection(ReadDirection value) {
    Log.debug('saveReadDirection:${value.name}');
    readDirection.value = value;
    _save();
  }

  static saveUseThirdPartyViewer(bool value) {
    Log.debug('saveUseThirdPartyViewer:$value');
    useThirdPartyViewer.value = value;
    _save();
  }

  static saveThirdPartyViewerPath(String? value) {
    Log.debug('saveThirdPartyViewerPath:$value');
    thirdPartyViewerPath.value = value;
    _save();
  }

  static saveEnablePageTurnAnime(bool value) {
    Log.debug('saveEnablePageTurnAnime:$value');
    enablePageTurnAnime.value = value;
    _save();
  }

  static saveEnableDoubleTapToScaleUp(bool value) {
    Log.debug('saveEnableDoubleTapToScaleUp:$value');
    enableDoubleTapToScaleUp.value = value;
    _save();
  }

  static saveTurnPageMode(TurnPageMode value) {
    Log.debug('saveTurnPageMode:${value.name}');
    turnPageMode.value = value;
    _save();
  }

  static savePreloadDistance(int value) {
    Log.debug('savePreloadDistance:$value');
    preloadDistance.value = value;
    _save();
  }

  static savePreloadPageCount(int value) {
    Log.debug('savePreloadPageCount:$value');
    preloadPageCount.value = value;
    _save();
  }

  static saveEnableAutoScaleUp(bool value) {
    Log.debug('saveEnableAutoScaleUp:$value');
    enableAutoScaleUp.value = value;
    _save();
  }

  static saveEnableContinuousHorizontalScroll(bool value) {
    Log.debug('saveEnableContinuousHorizontalScroll:$value');
    enableContinuousHorizontalScroll.value = value;
    _save();
  }

  static saveEnableDoubleColumn(bool value) {
    Log.debug('saveEnableDoubleColumn:$value');
    enableDoubleColumn.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('readSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableImmersiveMode': enableImmersiveMode.value,
      'showThumbnails': showThumbnails.value,
      'showStatusInfo': showStatusInfo.value,
      'enablePageTurnAnime': enablePageTurnAnime.value,
      'enableDoubleTapToScaleUp': enableDoubleTapToScaleUp.value,
      'autoModeInterval': autoModeInterval.value,
      'autoModeStyle': autoModeStyle.value.index,
      'readDirection': readDirection.value.index,
      'useThirdPartyViewer': useThirdPartyViewer.value,
      'thirdPartyViewerPath': thirdPartyViewerPath.value,
      'turnPageMode': turnPageMode.value.index,
      'preloadDistance': preloadDistance.value,
      'preloadPageCount': preloadPageCount.value,
      'enableContinuousHorizontalScroll': enableContinuousHorizontalScroll.value,
      'enableDoubleColumn': enableDoubleColumn.value,
      'enableAutoScaleUp': enableAutoScaleUp.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableImmersiveMode.value = map['enableImmersiveMode'];
    showThumbnails.value = map['showThumbnails'] ?? showThumbnails.value;
    showStatusInfo.value = map['showStatusInfo'] ?? showStatusInfo.value;
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    enableDoubleTapToScaleUp.value = map['enableDoubleTapToScaleUp'] ?? enableDoubleTapToScaleUp.value;
    autoModeInterval.value = map['autoModeInterval'] ?? autoModeInterval.value;
    autoModeStyle.value = AutoModeStyle.values[map['autoModeStyle'] ?? AutoModeStyle.scroll.index];
    readDirection.value = ReadDirection.values[map['readDirection']];
    useThirdPartyViewer.value = map['useThirdPartyViewer'] ?? useThirdPartyViewer.value;
    thirdPartyViewerPath.value = map['thirdPartyViewerPath'];
    turnPageMode.value = TurnPageMode.values[map['turnPageMode']];
    preloadDistance.value = map['preloadDistance'];
    preloadPageCount.value = map['preloadPageCount'];
    enableContinuousHorizontalScroll.value = map['enableContinuousHorizontalScroll'] ?? enableContinuousHorizontalScroll.value;
    enableDoubleColumn.value = map['enableDoubleColumn'] ?? enableDoubleColumn.value;
    enableAutoScaleUp.value = map['enableAutoScaleUp'];
  }
}
