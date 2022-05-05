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

class ReadSetting {
  static RxBool enableImmersiveMode = true.obs;
  static RxBool showStatusInfo = true.obs;
  static Rx<ReadDirection> readDirection = ReadDirection.top2bottom.obs;
  static RxBool enablePageTurnAnime = true.obs;
  static Rx<TurnPageMode> turnPageMode = TurnPageMode.adaptive.obs;
  static RxInt preloadDistance = 1.obs;
  static RxInt preloadPageCount = 1.obs;
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
    enableImmersiveMode.value = value;
    _save();
  }

  static saveShowStatusInfo(bool value) {
    showStatusInfo.value = value;
    _save();
  }

  static saveReadDirection(ReadDirection value) {
    readDirection.value = value;
    _save();
  }

  static saveEnablePageTurnAnime(bool value) {
    enablePageTurnAnime.value = value;
    _save();
  }

  static saveTurnPageMode(TurnPageMode value) {
    turnPageMode.value = value;
    _save();
  }

  static savePreloadDistance(int value) {
    preloadDistance.value = value;
    _save();
  }

  static savePreloadPageCount(int value) {
    preloadPageCount.value = value;
    _save();
  }

  static saveEnableAutoScaleUp(bool value) {
    enableAutoScaleUp.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('readSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableImmersiveMode': enableImmersiveMode.value,
      'showStatusInfo': showStatusInfo.value,
      'readDirection': readDirection.value.index,
      'enablePageTurnAnime': enablePageTurnAnime.value,
      'turnPageMode': turnPageMode.value.index,
      'preloadDistance': preloadDistance.value,
      'preloadPageCount': preloadPageCount.value,
      'enableAutoScaleUp': enableAutoScaleUp.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableImmersiveMode.value = map['enableImmersiveMode'];
    showStatusInfo.value = map['showStatusInfo'] ?? showStatusInfo.value;
    readDirection.value = ReadDirection.values[map['readDirection']];
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    turnPageMode.value = TurnPageMode.values[map['turnPageMode']];
    preloadDistance.value = map['preloadDistance'];
    preloadPageCount.value = map['preloadPageCount'];
    enableAutoScaleUp.value = map['enableAutoScaleUp'];
  }
}
