import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class AdvancedSetting {
  static RxBool enableLogging = true.obs;
  static RxBool enableVerboseLogging = kDebugMode.obs;
  static RxBool enableCheckUpdate = true.obs;
  static RxBool enableCheckClipboard = true.obs;

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('advancedSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init AdvancedSetting success', false);
    } else {
      Log.debug('init AdvancedSetting success: default', false);
    }
  }

  static saveEnableLogging(bool enableLogging) {
    Log.debug('saveEnableLogging:$enableLogging');
    AdvancedSetting.enableLogging.value = enableLogging;
    _save();
  }

  static saveEnableVerboseLogging(bool enableVerboseLogging) {
    Log.debug('saveEnableVerboseLogging:$enableVerboseLogging');
    AdvancedSetting.enableVerboseLogging.value = enableVerboseLogging;
    _save();
  }

  static saveEnableCheckUpdate(bool enableCheckUpdate) {
    Log.debug('saveEnableCheckUpdate:$enableCheckUpdate');
    AdvancedSetting.enableCheckUpdate.value = enableCheckUpdate;
    _save();
  }

  static saveEnableCheckClipboard(bool enableCheckClipboard) {
    Log.debug('saveEnableCheckClipboard:$enableCheckClipboard');
    AdvancedSetting.enableCheckClipboard.value = enableCheckClipboard;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('advancedSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableLogging': enableLogging.value,
      'enableVerboseLogging': enableVerboseLogging.value,
      'enableCheckUpdate': enableCheckUpdate.value,
      'enableCheckClipboard': enableCheckClipboard.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableLogging.value = map['enableLogging'];
    enableVerboseLogging.value = map['enableVerboseLogging'] ?? enableVerboseLogging.value;
    enableCheckUpdate.value = map['enableCheckUpdate'] ?? enableCheckUpdate.value;
    enableCheckClipboard.value = map['enableCheckClipboard'] ?? enableCheckClipboard.value;
  }
}
