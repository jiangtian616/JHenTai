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
  static RxDouble autoModeInterval = 2.0.obs;
  static Rx<AutoModeStyle> autoModeStyle = AutoModeStyle.turnPage.obs;
  static Rx<ReadDirection> readDirection = ReadDirection.top2bottom.obs;
  static Rx<TurnPageMode> turnPageMode = TurnPageMode.adaptive.obs;
  static RxInt preloadDistance = 1.obs;
  static RxInt preloadPageCount = 1.obs;
  static RxBool enableContinuousHorizontalScroll = false.obs;
  static RxBool enableAutoScaleUp = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('readSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init ReadSetting success', false);
    } else {
      Log.verbose('init ReadSetting success: default', false);
    }
  }

  static saveEnableImmersiveMode(bool value) {
    Log.verbose('saveEnableImmersiveMode:$value');
    enableImmersiveMode.value = value;
    _save();
  }

  static saveShowThumbnails(bool value) {
    Log.verbose('saveShowThumbnails:$value');
    showThumbnails.value = value;
    _save();
  }

  static saveShowStatusInfo(bool value) {
    Log.verbose('saveShowStatusInfo:$value');
    showStatusInfo.value = value;
    _save();
  }

  static saveAutoModeInterval(double value) {
    Log.verbose('saveAutoModeInterval:$value');
    autoModeInterval.value = value;
    _save();
  }

  static saveAutoModeStyle(AutoModeStyle value) {
    Log.verbose('saveAutoModeStyle:${value.name}');
    autoModeStyle.value = value;
    _save();
  }

  static saveReadDirection(ReadDirection value) {
    Log.verbose('saveReadDirection:${value.name}');
    readDirection.value = value;
    _save();
  }

  static saveEnablePageTurnAnime(bool value) {
    Log.verbose('saveEnablePageTurnAnime:$value');
    enablePageTurnAnime.value = value;
    _save();
  }

  static saveTurnPageMode(TurnPageMode value) {
    Log.verbose('saveTurnPageMode:${value.name}');
    turnPageMode.value = value;
    _save();
  }

  static savePreloadDistance(int value) {
    Log.verbose('savePreloadDistance:$value');
    preloadDistance.value = value;
    _save();
  }

  static savePreloadPageCount(int value) {
    Log.verbose('savePreloadPageCount:$value');
    preloadPageCount.value = value;
    _save();
  }

  static saveEnableAutoScaleUp(bool value) {
    Log.verbose('saveEnableAutoScaleUp:$value');
    enableAutoScaleUp.value = value;
    _save();
  }

  static saveEnableContinuousHorizontalScroll(bool value) {
    Log.verbose('saveEnableContinuousHorizontalScroll:$value');
    enableContinuousHorizontalScroll.value = value;
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
      'autoModeInterval': autoModeInterval.value,
      'autoModeStyle': autoModeStyle.value.index,
      'readDirection': readDirection.value.index,
      'turnPageMode': turnPageMode.value.index,
      'preloadDistance': preloadDistance.value,
      'preloadPageCount': preloadPageCount.value,
      'enableContinuousHorizontalScroll': enableContinuousHorizontalScroll.value,
      'enableAutoScaleUp': enableAutoScaleUp.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableImmersiveMode.value = map['enableImmersiveMode'];
    showThumbnails.value = map['showThumbnails'] ?? showThumbnails.value;
    showStatusInfo.value = map['showStatusInfo'] ?? showStatusInfo.value;
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    autoModeInterval.value = map['autoModeInterval'] ?? autoModeInterval.value;
    autoModeStyle.value = AutoModeStyle.values[map['autoModeStyle'] ?? AutoModeStyle.scroll.index];
    readDirection.value = ReadDirection.values[map['readDirection']];
    turnPageMode.value = TurnPageMode.values[map['turnPageMode']];
    preloadDistance.value = map['preloadDistance'];
    preloadPageCount.value = map['preloadPageCount'];
    enableContinuousHorizontalScroll.value = map['enableContinuousHorizontalScroll'] ?? enableContinuousHorizontalScroll.value;
    enableAutoScaleUp.value = map['enableAutoScaleUp'];
  }
}
