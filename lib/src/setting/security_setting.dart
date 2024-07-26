import 'dart:convert';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/log.dart';
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
  Future<void> doOnInit() async {
    if (GetPlatform.isMobile) {
      List<BiometricType> types = await LocalAuthentication().getAvailableBiometrics();
      supportBiometricAuth = types.isNotEmpty;
      Log.debug('Init SecuritySetting.supportBiometricAuth: $supportBiometricAuth');
    }
  }

  @override
  void doOnReady() {}

  Future<void> saveEnableBlur(bool enableBlur) async {
    Log.debug('saveEnableBlur:$enableBlur');
    this.enableBlur.value = enableBlur;
    await save();

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

  Future<void> savePassword(String rawPassword) async {
    String md5 = keyToMd5(rawPassword);
    Log.debug('saveEncryptedPassword:$md5');
    this.encryptedPassword.value = md5;
    await save();
  }

  Future<void> saveEnablePasswordAuth(bool enablePasswordAuth) async {
    Log.debug('saveEnablePasswordAuth:$enablePasswordAuth');
    this.enablePasswordAuth.value = enablePasswordAuth;
    await save();
  }

  Future<void> saveEnableBiometricAuth(bool enableBiometricAuth) async {
    Log.debug('saveEnableBiometricAuth:$enableBiometricAuth');
    this.enableBiometricAuth.value = enableBiometricAuth;
    await save();
  }

  Future<void> saveEnableAuthOnResume(bool enableAuthOnResume) async {
    Log.debug('saveEnableAuthOnResume:$enableAuthOnResume');
    this.enableAuthOnResume.value = enableAuthOnResume;
    await save();

    if (enableAuthOnResume) {
      saveEnableBlur(true);
    }
  }

  Future<void> saveHideImagesInAlbum(bool hideImagesInAlbum) async {
    Log.debug('saveHideImagesInAlbum:$hideImagesInAlbum');
    this.hideImagesInAlbum.value = hideImagesInAlbum;
    await save();

    Directory directory = Directory(DownloadSetting.downloadPath.value);
    File file = File(join(directory.path, '.nomedia'));
    if (hideImagesInAlbum) {
      file.create();
    } else {
      file.delete().ignore();
    }
  }
}
