import 'package:get/get.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

class MouseSetting {
  static RxDouble wheelScrollSpeed = 5.0.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('mouseSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init MouseSetting success', false);
    } else {
      Log.debug('init MouseSetting success: default', false);
    }
  }

  static saveWheelScrollSpeed(double wheelScrollSpeed) {
    Log.debug('saveWheelScrollSpeed:$wheelScrollSpeed');
    MouseSetting.wheelScrollSpeed.value = wheelScrollSpeed;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('mouseSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'wheelScrollSpeed': wheelScrollSpeed.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    wheelScrollSpeed.value = map['wheelScrollSpeed'] ?? wheelScrollSpeed.value;
  }
}
