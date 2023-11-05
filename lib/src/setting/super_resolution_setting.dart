import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

enum ModelType {
  ESRGAN(
    'realesrgan',
    'realesrgan-x4plus',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip',
    'realesrgan-ncnn-vulkan.exe',
    'realesrgan-ncnn-vulkan',
    'realesrgan-ncnn-vulkan',
    '',
    '',
    '',
    'models',
  ),
  ESRGAN_ANIME(
    'realesrgan',
    'realesrgan-x4plus-anime',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip',
    'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip',
    'realesrgan-ncnn-vulkan.exe',
    'realesrgan-ncnn-vulkan',
    'realesrgan-ncnn-vulkan',
    '',
    '',
    '',
    'models',
  ),
  CUGAN(
    'realcugan',
    'realcugan',
    'https://github.com/nihui/realcugan-ncnn-vulkan/releases/download/20220728/realcugan-ncnn-vulkan-20220728-windows.zip',
    'https://github.com/nihui/realcugan-ncnn-vulkan/releases/download/20220728/realcugan-ncnn-vulkan-20220728-ubuntu.zip',
    'https://github.com/nihui/realcugan-ncnn-vulkan/releases/download/20220728/realcugan-ncnn-vulkan-20220728-macos.zip',
    'realcugan-ncnn-vulkan.exe',
    'realcugan-ncnn-vulkan',
    'realcugan-ncnn-vulkan',
    'realcugan-ncnn-vulkan-20220728-windows',
    'realcugan-ncnn-vulkan-20220728-macos',
    'realcugan-ncnn-vulkan-20220728-ubuntu',
    'models-se',
  );

  const ModelType(
    this.type,
    this.subType,
    this.windowsDownloadUrl,
    this.linuxDownloadUrl,
    this.macDownloadUrl,
    this.windowsExecutableName,
    this.macOSExecutableName,
    this.linuxExecutableName,
    this.windowsModelExtractPath,
    this.macOSModelExtractPath,
    this.linuxModelExtractPath,
    this.modelRelativePath,
  );

  final String type;

  final String subType;

  final String windowsDownloadUrl;

  final String linuxDownloadUrl;

  final String macDownloadUrl;

  final String windowsExecutableName;

  final String macOSExecutableName;

  final String linuxExecutableName;

  final String windowsModelExtractPath;

  final String macOSModelExtractPath;

  final String linuxModelExtractPath;

  final String modelRelativePath;
}

class SuperResolutionSetting {
  static RxnString modelDirectoryPath = RxnString(null);
  static Rx<ModelType> model = Rx<ModelType>(ModelType.CUGAN);
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

  static saveModel(ModelType model) {
    Log.debug('saveModel:$model');
    SuperResolutionSetting.model.value = model;
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
      'model': model.value?.index,
      'gpuId': gpuId.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    modelDirectoryPath.value = map['modelDirectoryPath'];
    model.value = map['model'] == null ? ModelType.CUGAN : ModelType.values[map['model']];
    gpuId.value = map['gpuId'] ?? gpuId.value;
  }
}
