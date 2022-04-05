import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:local_auth/local_auth.dart';

import '../service/storage_service.dart';

class AdvancedSetting {
  static RxBool enableDomainFronting = false.obs;
  static RxBool enableLogging = true.obs;
  static RxBool enableFingerPrintLock = false.obs;

  static bool supportFingerPrintLock = false;

  static Future<void> init() async {
    supportFingerPrintLock = (await LocalAuthentication().getAvailableBiometrics()).contains(BiometricType.fingerprint);

    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('advancedSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init AdvancedSetting success', false);
    } else {
      Log.verbose('init AdvancedSetting success: default', false);
    }
  }

  static saveEnableDomainFronting(bool enableDomainFronting) {
    AdvancedSetting.enableDomainFronting.value = enableDomainFronting;
    _save();
  }

  static saveEnableLogging(bool enableLogging) {
    AdvancedSetting.enableLogging.value = enableLogging;
    _save();
  }

  static saveEnableFingerPrintLock(bool enableFingerPrintLock) {
    AdvancedSetting.enableFingerPrintLock.value = enableFingerPrintLock;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('advancedSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableDomainFronting': enableDomainFronting.value,
      'enableLogging': enableLogging.value,
      'enableFingerPrintLock': enableFingerPrintLock.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableDomainFronting.value = map['enableDomainFronting'];
    enableLogging.value = map['enableLogging'];
    enableFingerPrintLock.value = map['enableFingerPrintLock'];
  }
}
