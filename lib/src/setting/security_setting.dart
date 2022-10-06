import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:local_auth/local_auth.dart';

import '../service/storage_service.dart';

class SecuritySetting {
  static RxBool enableBlur = false.obs;
  static RxBool enableBiometricLock = false.obs;
  static RxBool enableBiometricLockOnResume = false.obs;

  static bool supportBiometricLock = false;

  static Future<void> init() async {
    if (GetPlatform.isDesktop) {
      return;
    }

    List<BiometricType> types = await LocalAuthentication().getAvailableBiometrics();
    supportBiometricLock = types.contains(BiometricType.fingerprint) || types.contains(BiometricType.face);

    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('securitySetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SecuritySetting success', false);
    } else {
      Log.debug('init SecuritySetting success: default', false);
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
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemStatusBarContrastEnforced: true),
    );
  }

  static saveEnableBiometricLock(bool enableBiometricLock) {
    Log.debug('saveEnableBiometricLock:$enableBiometricLock');
    SecuritySetting.enableBiometricLock.value = enableBiometricLock;
    _save();
  }

  static saveEnableBiometricLockOnResume(bool enableBiometricLockOnResume) {
    Log.debug('saveEnableBiometricLockOnResume:$enableBiometricLockOnResume');
    SecuritySetting.enableBiometricLockOnResume.value = enableBiometricLockOnResume;
    _save();

    if (!GetPlatform.isAndroid) {
      return;
    }
    if (enableBiometricLockOnResume) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemStatusBarContrastEnforced: true),
    );
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('securitySetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableBlur': enableBlur.value,
      'enableBiometricLock': enableBiometricLock.value,
      'enableBiometricLockOnResume': enableBiometricLockOnResume.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableBlur.value = map['enableBlur'] ?? enableBlur.value;
    enableBiometricLock.value = map['enableBiometricLock'] ?? enableBiometricLock.value;
    enableBiometricLockOnResume.value = map['enableBiometricLockOnResume'] ?? enableBiometricLockOnResume.value;
  }
}
