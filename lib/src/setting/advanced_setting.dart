import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

AdvancedSetting advancedSetting = AdvancedSetting();

class AdvancedSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxBool enableLogging = true.obs;
  RxBool enableVerboseLogging = kDebugMode.obs;
  RxBool enableCheckUpdate = true.obs;
  RxBool enableCheckClipboard = true.obs;
  RxBool inNoImageMode = false.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.advancedSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    enableLogging.value = map['enableLogging'];
    enableVerboseLogging.value = map['enableVerboseLogging'] ?? enableVerboseLogging.value;
    enableCheckUpdate.value = map['enableCheckUpdate'] ?? enableCheckUpdate.value;
    enableCheckClipboard.value = map['enableCheckClipboard'] ?? enableCheckClipboard.value;
    inNoImageMode.value = map['inNoImageMode'] ?? inNoImageMode.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'enableLogging': enableLogging.value,
      'enableVerboseLogging': enableVerboseLogging.value,
      'enableCheckUpdate': enableCheckUpdate.value,
      'enableCheckClipboard': enableCheckClipboard.value,
      'inNoImageMode': inNoImageMode.value,
    });
  }

  @override
  Future<void> doOnInit() async {}

  @override
  void doOnReady() {}

  Future<void> saveEnableLogging(bool enableLogging) async {
    log.debug('saveEnableLogging:$enableLogging');
    this.enableLogging.value = enableLogging;
    await save();
  }

  Future<void> saveEnableVerboseLogging(bool enableVerboseLogging) async {
    log.debug('saveEnableVerboseLogging:$enableVerboseLogging');
    this.enableVerboseLogging.value = enableVerboseLogging;
    await save();
  }

  Future<void> saveEnableCheckUpdate(bool enableCheckUpdate) async {
    log.debug('saveEnableCheckUpdate:$enableCheckUpdate');
    this.enableCheckUpdate.value = enableCheckUpdate;
    await save();
  }

  Future<void> saveEnableCheckClipboard(bool enableCheckClipboard) async {
    log.debug('saveEnableCheckClipboard:$enableCheckClipboard');
    this.enableCheckClipboard.value = enableCheckClipboard;
    await save();
  }

  Future<void> saveInNoImageMode(bool inNoImageMode) async {
    log.debug('saveInNoImageMode:$inNoImageMode');
    this.inNoImageMode.value = inNoImageMode;
    await save();
  }
}
