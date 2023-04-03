import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class SuperResolutionSetting {
  static RxnString executableFilePath = RxnString(null);
  static RxInt upSamplingScale = 2.obs;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('SuperResolutionSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SuperResolutionSetting success', false);
    } else {
      Log.debug('init SuperResolutionSetting success: default', false);
    }
  }

  static saveExecutableFilePath(String? executableFilePath) {
    Log.debug('saveExecutableFilePath:$executableFilePath');
    SuperResolutionSetting.executableFilePath.value = executableFilePath;
    _save();
  }

  static saveUpSamplingScale(int upSamplingScale) {
    Log.debug('saveUpSamplingScale:$upSamplingScale');
    SuperResolutionSetting.upSamplingScale.value = upSamplingScale;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('SuperResolutionSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'executableFilePath': executableFilePath.value,
      'upSamplingScale': upSamplingScale.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    executableFilePath.value = map['executableFilePath'];
    upSamplingScale.value = map['upSamplingScale'] ?? upSamplingScale.value;
  }
}
