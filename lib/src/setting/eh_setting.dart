import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class EHSetting {
  static RxString site = 'EH'.obs;
  static RxBool redirect2EH = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('EHSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init EHSetting success', false);
    } else {
      Log.verbose('init EHSetting success: default', false);
    }
  }

  static saveSite(String site) {
    EHSetting.site.value = site;
    _save();
  }

  static saveRedirect2EH(bool redirect2EH) {
    EHSetting.redirect2EH.value = redirect2EH;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('EHSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'site': site.value,
      'redirect2EH': redirect2EH.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    site.value = map['site'];
    redirect2EH.value = map['redirect2EH'];
  }
}
