import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:local_auth/local_auth.dart';

import '../service/storage_service.dart';

class SecuritySetting {
  static RxBool enableBlur = false.obs;
  static RxBool enableFingerPrintLock = false.obs;

  static bool supportFingerPrintLock = false;

  static Future<void> init() async {
    if (GetPlatform.isDesktop) {
      return;
    }
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
    Log.verbose('saveEnableBlur:$enableBlur');

    SecuritySetting.enableBlur.value = enableBlur;
    _save();

    if (!GetPlatform.isAndroid) {
      return;
    }
    if (enableBlur) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }

    /// resume appbar color
    SystemChrome.setSystemUIOverlayStyle(
        Get.theme.appBarTheme.systemOverlayStyle!.copyWith(systemStatusBarContrastEnforced: true));
  }

  static saveEnableFingerPrintLock(bool enableFingerPrintLock) {
    Log.verbose('saveEnableFingerPrintLock:$enableFingerPrintLock');
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
