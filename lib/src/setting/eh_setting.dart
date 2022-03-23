import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class EHSetting {
  static RxString site = 'EH'.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('EHSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init EHSetting success', false);
    }
  }

  static saveSite(String site) {
    EHSetting.site.value = site;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('EHSetting', _toMap());
  }

  static void clear() {
    site.value = 'EH';
    Get.find<StorageService>().remove('EHSetting');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'site': site.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    site.value = map['site'];
  }
}
