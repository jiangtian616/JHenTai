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
  static Rx<ReadDirection> readDirection = ReadDirection.top2bottom.obs;
  static RxBool enablePageTurnAnime = true.obs;
  static Rx<TurnPageMode> turnPageMode = TurnPageMode.image.obs;
  static RxInt preloadDistance = 1.obs;
  static RxInt preloadPageCount = 1.obs;

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

  static Future<void> _save() async {
    await Get.find<StorageService>().write('readSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'readDirection': readDirection.value.index,
      'enablePageTurnAnime': enablePageTurnAnime.value,
      'turnPageMode': turnPageMode.value.index,
      'preloadDistance': preloadDistance.value,
      'preloadPageCount': preloadPageCount.value,
      'enableImmersiveMode': enableImmersiveMode.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    readDirection.value = ReadDirection.values[map['readDirection']];
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    turnPageMode.value = TurnPageMode.values[map['turnPageMode']];
    preloadDistance.value = map['preloadDistance'];
    preloadPageCount.value = map['preloadPageCount'];
    enableImmersiveMode.value = map['enableImmersiveMode'];
  }
}
