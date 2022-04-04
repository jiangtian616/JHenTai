import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

enum ReadDirection {
  top2bottom,
  left2right,
  right2left,
}

class ReadSetting {
  static Rx<ReadDirection> readDirection = ReadDirection.top2bottom.obs;
  static RxBool enablePageTurnAnime = true.obs;
  static RxInt preloadDistance = 1.obs;
  static RxInt preloadPageCount = 1.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('readSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init ReadSetting success', false);
    } else {
      Log.info('init ReadSetting success: default', false);
    }
  }

  static saveReadDirection(ReadDirection value) {
    readDirection.value = value;
    _save();
  }

  static saveEnablePageTurnAnime(bool value) {
    enablePageTurnAnime.value = value;
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
      'preloadDistance': preloadDistance.value,
      'preloadPageCount': preloadPageCount.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    readDirection.value = ReadDirection.values[map['readDirection']];
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
    preloadDistance.value = map['preloadDistance'];
    preloadPageCount.value = map['preloadPageCount'];
  }
}
