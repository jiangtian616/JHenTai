import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/inference/onnx_model_store.dart';
import '../service/jh_service.dart';

SuperResolutionSetting superResolutionSetting = SuperResolutionSetting();

class SuperResolutionSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  RxnString modelDirectoryPath = RxnString(null);
  Rx<ModelType> model = Rx<ModelType>(ModelType.CUGAN);
  RxInt gpuId = 0.obs;

  /// 超分引擎：ncnn-vulkan 外部二进制或 AI Core 的 ONNX 分块推理。
  Rx<SuperResolutionEngine> engine = Rx<SuperResolutionEngine>(
    SuperResolutionEngine.ncnnVulkan,
  );

  /// The active ONNX super-resolution model manifest id. Both current models
  /// (anime 6B and the lighter 4B32F) are x4 with the same input contract, so
  /// the engine itself is unaffected by the choice.
  RxString onnxModelId = RxString(OnnxModelStore.superResolutionManifestId);

  @override
  ConfigEnum get configEnum => ConfigEnum.superResolutionSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    modelDirectoryPath.value = map['modelDirectoryPath'];
    model.value =
        map['model'] == null ? ModelType.CUGAN : ModelType.values[map['model']];
    gpuId.value = map['gpuId'] ?? gpuId.value;
    engine.value = SuperResolutionEngine.values.firstWhere(
      (value) => value.name == map['engine'],
      orElse: () => SuperResolutionEngine.ncnnVulkan,
    );
    final String? savedOnnxModelId = map['onnxModelId'];
    if (savedOnnxModelId != null &&
        OnnxModelStore.instance.manifestOf(savedOnnxModelId)?.kind ==
            'superResolution') {
      onnxModelId.value = savedOnnxModelId;
    }
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'modelDirectoryPath': modelDirectoryPath.value,
      'model': model.value.index,
      'gpuId': gpuId.value,
      'engine': engine.value.name,
      'onnxModelId': onnxModelId.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveModelDirectoryPath(String? modelDirectoryPath) async {
    log.debug('saveModelDirectoryPath:$modelDirectoryPath');
    this.modelDirectoryPath.value = modelDirectoryPath;
    await saveBeanConfig();
  }

  Future<void> saveModel(ModelType model) async {
    log.debug('saveModel:$model');
    this.model.value = model;
    await saveBeanConfig();
  }

  Future<void> saveGpuId(int gpuId) async {
    log.debug('saveGpuId:$gpuId');
    this.gpuId.value = gpuId;
    await saveBeanConfig();
  }

  Future<void> saveEngine(SuperResolutionEngine engine) async {
    log.debug('saveSuperResolutionEngine:$engine');
    this.engine.value = engine;
    await saveBeanConfig();
  }

  Future<void> saveOnnxModelId(String modelId) async {
    log.debug('saveOnnxModelId:$modelId');
    onnxModelId.value = modelId;
    await saveBeanConfig();
  }
}

/// 超分推理引擎：现有 ncnn-vulkan 外部二进制，或统一推理后端的 ONNX 引擎。
enum SuperResolutionEngine { ncnnVulkan, onnx }

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
