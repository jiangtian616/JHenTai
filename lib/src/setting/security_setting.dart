import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:local_auth/local_auth.dart';

import '../service/storage_service.dart';

class SecuritySetting {
  static RxBool enableBlur = false.obs;
  static RxnString encryptedPassword = RxnString(null);
  static RxBool enablePasswordAuth = false.obs;
  static RxBool enableBiometricAuth = false.obs;
  static RxBool enableAuthOnResume = false.obs;

  static bool supportBiometricAuth = false;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('securitySetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SecuritySetting success', false);
    } else {
      Log.debug('init SecuritySetting success: default', false);
    }

    if (GetPlatform.isMobile) {
      List<BiometricType> types = await LocalAuthentication().getAvailableBiometrics();
      supportBiometricAuth = types.isNotEmpty;
      Log.debug('supportBiometricAuth:$supportBiometricAuth');
    }
  }

  static saveEnableBlur(bool enableBlur) {
    Log.debug('saveEnableBlur:$enableBlur');

    SecuritySetting.enableBlur.value = enableBlur;
    _save();

    if (!GetPlatform.isAndroid) {
      return;
    }
    if (enableBlur) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      saveEnableAuthOnResume(false);
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemStatusBarContrastEnforced: true),
    );
  }

  static savePassword(String rawPassword) {
    String md5 = keyToMd5(rawPassword);
    Log.debug('saveEncryptedPassword:$md5');
    SecuritySetting.encryptedPassword.value = md5;
    _save();
  }

  static saveEnablePasswordAuth(bool enablePasswordAuth) {
    Log.debug('saveEnablePasswordAuth:$enablePasswordAuth');
    SecuritySetting.enablePasswordAuth.value = enablePasswordAuth;
    _save();
  }

  static saveEnableBiometricAuth(bool enableBiometricAuth) {
    Log.debug('saveEnableBiometricAuth:$enableBiometricAuth');
    SecuritySetting.enableBiometricAuth.value = enableBiometricAuth;
    _save();
  }

  static saveEnableAuthOnResume(bool enableAuthOnResume) {
    Log.debug('saveEnableAuthOnResume:$enableAuthOnResume');
    SecuritySetting.enableAuthOnResume.value = enableAuthOnResume;
    _save();

    if (enableAuthOnResume) {
      saveEnableBlur(true);
    }
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('securitySetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableBlur': enableBlur.value,
      'encryptedPassword': encryptedPassword.value,
      'enablePasswordAuth': enablePasswordAuth.value,
      'enableBiometricAuth': enableBiometricAuth.value,
      'enableAuthOnResume': enableAuthOnResume.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableBlur.value = map['enableBlur'] ?? enableBlur.value;
    encryptedPassword.value = map['encryptedPassword'] ?? encryptedPassword.value;
    enablePasswordAuth.value = map['enablePasswordAuth'] ?? enablePasswordAuth.value;
    enableBiometricAuth.value = map['enableBiometricAuth'] ?? enableBiometricAuth.value;
    enableAuthOnResume.value = map['enableAuthOnResume'] ?? enableAuthOnResume.value;
  }
}
