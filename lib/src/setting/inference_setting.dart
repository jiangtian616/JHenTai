import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';

import '../service/jh_service.dart';
import '../service/log.dart';

/// 全局"推理后端"设置：OCR 与图像超分共用一个入口。
InferenceSetting inferenceSetting = InferenceSetting();

/// 后端选择模式。
enum InferenceBackendMode {
  /// 自动检测：按平台与可用性挑选最佳后端，GPU 不可用时回退 CPU。
  auto,

  /// 手动指定：使用 [InferenceSetting.preferredBackend]。
  manual,

  /// 强制 CPU。
  cpu,
}

/// 推理后端（执行提供器）。顺序即各平台探测时的优先级参考。
enum InferenceBackend {
  auto,

  /// 通用 CPU 后端（所有平台兜底）。
  cpu,

  /// Windows DirectX 12 —— 通吃 NVIDIA / AMD / Intel。
  directml,

  /// NVIDIA GPU（Linux / Windows，需运行时实际提供 CUDA provider）。
  cuda,

  /// Intel CPU/GPU（Linux）。
  openvino,

  /// Android Neural Network API（API 27+，可路由到 NPU/GPU/DSP）。
  nnapi,

  /// Apple CoreML（iOS / macOS，Apple Neural Engine）。
  coreml,

  /// Vulkan（ncnn-vulkan 超分使用，桌面）。
  vulkan,

  /// 浮点加速 CPU 后端（ARM 设备常用）。
  xnnpack,
}

/// 使用推理后端的业务领域。
enum InferenceDomain {
  /// 图片文字识别（图片翻译的 OCR 阶段）。
  ocr,

  /// 图像超分（Real-ESRGAN / CUGAN）。
  superResolution,
}

class InferenceSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  /// 后端选择模式。
  final Rx<InferenceBackendMode> mode = InferenceBackendMode.auto.obs;

  /// 手动模式下指定的后端。
  final Rx<InferenceBackend> preferredBackend = InferenceBackend.auto.obs;

  /// Android 上是否允许 NNAPI 硬件加速（不可用时自动回退 CPU）。
  final RxBool enableNnapi = true.obs;

  /// 后端不可用时是否允许回退 CPU。
  final RxBool enableCpuFallback = true.obs;

  /// 最近一次从 ONNX Runtime 读取到的 provider 摘要。
  final RxnString detectedDeviceLabel = RxnString();

  /// 最近一次实际运行时/模型探测耗时摘要。
  final RxnString benchmarkSummary = RxnString();

  @override
  ConfigEnum get configEnum => ConfigEnum.inferenceSetting;

  @override
  void applyBeanConfig(String configString) {
    final Map<String, dynamic> config = jsonDecode(configString);
    mode.value = InferenceBackendMode.values.firstWhere(
      (value) => value.name == config['mode'],
      orElse: () => InferenceBackendMode.auto,
    );
    preferredBackend.value = InferenceBackend.values.firstWhere(
      (value) => value.name == config['preferredBackend'],
      orElse: () => InferenceBackend.auto,
    );
    enableNnapi.value = config['enableNnapi'] ?? true;
    enableCpuFallback.value = config['enableCpuFallback'] ?? true;
    detectedDeviceLabel.value = config['detectedDeviceLabel'];
    benchmarkSummary.value = config['benchmarkSummary'];
  }

  @override
  String toConfigString() => jsonEncode({
    'mode': mode.value.name,
    'preferredBackend': preferredBackend.value.name,
    'enableNnapi': enableNnapi.value,
    'enableCpuFallback': enableCpuFallback.value,
    'detectedDeviceLabel': detectedDeviceLabel.value,
    'benchmarkSummary': benchmarkSummary.value,
  });

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> saveMode(InferenceBackendMode value) async {
    log.debug('saveInferenceBackendMode:$value');
    mode.value = value;
    await saveBeanConfig();
  }

  Future<void> savePreferredBackend(InferenceBackend value) async {
    log.debug('saveInferencePreferredBackend:$value');
    preferredBackend.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableNnapi(bool value) async {
    log.debug('saveInferenceEnableNnapi:$value');
    enableNnapi.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableCpuFallback(bool value) async {
    log.debug('saveInferenceEnableCpuFallback:$value');
    enableCpuFallback.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDetectedDeviceLabel(String? value) async {
    log.debug('saveInferenceDetectedDeviceLabel:$value');
    detectedDeviceLabel.value = value;
    await saveBeanConfig();
  }

  Future<void> saveBenchmarkSummary(String? value) async {
    log.debug('saveInferenceBenchmarkSummary:$value');
    benchmarkSummary.value = value;
    await saveBeanConfig();
  }
}

/// 后端的 i18n 展示名（key: `inferenceBackendXxx`）。
extension InferenceBackendLabel on InferenceBackend {
  String get label =>
      'inferenceBackend${name[0].toUpperCase()}${name.substring(1)}'.tr;
}

/// 模式的 i18n 展示名（key: `inferenceModeXxx`）。
extension InferenceBackendModeLabel on InferenceBackendMode {
  String get label =>
      'inferenceMode${name[0].toUpperCase()}${name.substring(1)}'.tr;
}
