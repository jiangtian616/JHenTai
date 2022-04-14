import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:local_auth/local_auth.dart';

import '../service/storage_service.dart';

class SecuritySetting {
  static RxBool enableBlur = false.obs;
  static RxBool enableFingerPrintLock = false.obs;

  static bool supportFingerPrintLock = false;

  static Future<void> init() async {
    supportFingerPrintLock = (await LocalAuthentication().getAvailableBiometrics()).contains(BiometricType.fingerprint);

    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('securitySetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init SecuritySetting success', false);
    } else {
      Log.verbose('init SecuritySetting success: default', false);
    }
  }

  static saveEnableBlur(bool enableBlur) {
    SecuritySetting.enableBlur.value = enableBlur;
    _save();
  }

  static saveEnableFingerPrintLock(bool enableFingerPrintLock) {
    SecuritySetting.enableFingerPrintLock.value = enableFingerPrintLock;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('securitySetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableBlur': enableBlur.value,
      'enableFingerPrintLock': enableFingerPrintLock.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableBlur.value = map['enableBlur'];
    enableFingerPrintLock.value = map['enableFingerPrintLock'];
  }
}
