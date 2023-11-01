import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class SuperResolutionSetting {
  static RxnString modelDirectoryPath = RxnString(null);
  static RxString modelType = 'realesrgan-x4plus'.obs;
  static RxInt gpuId = 0.obs;

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

  static saveModelType(String modelType) {
    Log.debug('saveModelType:$modelType');
    SuperResolutionSetting.modelType.value = modelType;
    _save();
  }
  
  static saveGpuId(int gpuId) {
    Log.debug('saveGpuId:$gpuId');
    SuperResolutionSetting.gpuId.value = gpuId;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('SuperResolutionSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'modelDirectoryPath': modelDirectoryPath.value,
      'modelType': modelType.value,
      'gpuId': gpuId.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    modelDirectoryPath.value = map['modelDirectoryPath'];
    modelType.value = map['modelType'] ?? modelType.value;
    gpuId.value = map['gpuId'] ?? gpuId.value;
  }
}
