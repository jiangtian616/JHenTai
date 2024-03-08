import 'package:get/get.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

class PerformanceSetting {
  static RxInt maxGalleryNum4Animation = 30.obs;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('performanceSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init PerformanceSetting success');
    } else {
      Log.debug('init PerformanceSetting success: default');
    }
  }

  static void setMaxGalleryNum4Animation(int value) {
    Log.debug('setMaxGalleryNum4Animation:$value');
    maxGalleryNum4Animation.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('performanceSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'maxGalleryNum4Animation': maxGalleryNum4Animation.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    maxGalleryNum4Animation.value = map['maxGalleryNum4Animation'] ?? maxGalleryNum4Animation.value;
  }
}
