import 'dart:convert';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart';

import '../service/jh_service.dart';

SecuritySetting securitySetting = SecuritySetting();

class SecuritySetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxBool enableBlur = false.obs;
  RxnString encryptedPassword = RxnString(null);
  RxBool enablePasswordAuth = false.obs;
  RxBool enableBiometricAuth = false.obs;
  RxBool enableAuthOnResume = false.obs;
  RxBool hideImagesInAlbum = false.obs;

  bool supportBiometricAuth = false;

  @override
  ConfigEnum get configEnum => ConfigEnum.securitySetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    enableBlur.value = map['enableBlur'] ?? enableBlur.value;
    encryptedPassword.value = map['encryptedPassword'] ?? encryptedPassword.value;
    enablePasswordAuth.value = map['enablePasswordAuth'] ?? enablePasswordAuth.value;
    enableBiometricAuth.value = map['enableBiometricAuth'] ?? enableBiometricAuth.value;
    enableAuthOnResume.value = map['enableAuthOnResume'] ?? enableAuthOnResume.value;
    hideImagesInAlbum.value = map['hideImagesInAlbum'] ?? hideImagesInAlbum.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'enableBlur': enableBlur.value,
      'encryptedPassword': encryptedPassword.value,
      'enablePasswordAuth': enablePasswordAuth.value,
      'enableBiometricAuth': enableBiometricAuth.value,
      'enableAuthOnResume': enableAuthOnResume.value,
      'hideImagesInAlbum': hideImagesInAlbum.value,
    });
  }

  @override
  Future<void> doInitBean() async {
    if (GetPlatform.isMobile) {
      List<BiometricType> types = await LocalAuthentication().getAvailableBiometrics();
      supportBiometricAuth = types.isNotEmpty;
      log.debug('Init SecuritySetting.supportBiometricAuth: $supportBiometricAuth');
    }

    if (GetPlatform.isAndroid) {
      ever(enableBlur, (_) {
        if (enableBlur.isTrue) {
          FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        } else {
          FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
          saveEnableAuthOnResume(false);
        }
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(systemStatusBarContrastEnforced: true),
        );
      });
    }

    ever(enableAuthOnResume, (_) {
      if (enableAuthOnResume.isTrue) {
        saveEnableBlur(true);
      }
    });

    ever(hideImagesInAlbum, (_) {
      Directory directory = Directory(downloadSetting.downloadPath.value);
      File file = File(join(directory.path, '.nomedia'));
      if (hideImagesInAlbum.isTrue) {
        file.create();
      } else {
        file.delete().ignore();
      }
    });
  }

  @override
  void doAfterBeanReady() {}

  Future<void> saveEnableBlur(bool enableBlur) async {
    log.debug('saveEnableBlur:$enableBlur');
    this.enableBlur.value = enableBlur;
    await save();
  }

  Future<void> savePassword(String rawPassword) async {
    String md5 = keyToMd5(rawPassword);
    log.debug('saveEncryptedPassword:$md5');
    this.encryptedPassword.value = md5;
    await save();
  }

  Future<void> saveEnablePasswordAuth(bool enablePasswordAuth) async {
    log.debug('saveEnablePasswordAuth:$enablePasswordAuth');
    this.enablePasswordAuth.value = enablePasswordAuth;
    await save();
  }

  Future<void> saveEnableBiometricAuth(bool enableBiometricAuth) async {
    log.debug('saveEnableBiometricAuth:$enableBiometricAuth');
    this.enableBiometricAuth.value = enableBiometricAuth;
    await save();
  }

  Future<void> saveEnableAuthOnResume(bool enableAuthOnResume) async {
    log.debug('saveEnableAuthOnResume:$enableAuthOnResume');
    this.enableAuthOnResume.value = enableAuthOnResume;
    await save();
  }

  Future<void> saveHideImagesInAlbum(bool hideImagesInAlbum) async {
    log.debug('saveHideImagesInAlbum:$hideImagesInAlbum');
    this.hideImagesInAlbum.value = hideImagesInAlbum;
    await save();
  }
}
