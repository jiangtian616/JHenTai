import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class SuperResolutionSetting {
  static RxnString modelDirectoryPath = RxnString(null);

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('SuperResolutionSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SuperResolutionSetting success', false);
    } else {
      Log.debug('init SuperResolutionSetting success: default', false);
    }
  }

  static saveModelDirectoryPath(String? modelDirectoryPath) {
    Log.debug('saveModelDirectoryPath:$modelDirectoryPath');
    SuperResolutionSetting.modelDirectoryPath.value = modelDirectoryPath;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('SuperResolutionSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'modelDirectoryPath': modelDirectoryPath.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    modelDirectoryPath.value = map['modelDirectoryPath'];
  }
}
