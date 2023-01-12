import 'package:get/get.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

class PreferenceSetting {
  static RxBool showR18GImageDirectly = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('preferenceSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init PreferenceSetting success', false);
    } else {
      Log.debug('init PreferenceSetting success: default', false);
    }
  }

  static saveShowR18GImageDirectly(bool showR18GImageDirectly) {
    Log.debug('saveShowR18GImageDirectly:$showR18GImageDirectly');
    PreferenceSetting.showR18GImageDirectly.value = showR18GImageDirectly;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('preferenceSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'showR18GImageDirectly': showR18GImageDirectly.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    showR18GImageDirectly.value = map['showR18GImageDirectly'] ?? showR18GImageDirectly.value;
  }
}
