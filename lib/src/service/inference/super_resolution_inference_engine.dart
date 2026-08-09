import 'inference_exception.dart';
import 'inference_task.dart';

/// 统一的图像超分推理入口。当前实现：ONNX（Real-ESRGAN / CUGAN）。
/// 框架阶段由 [NotConfiguredSuperResolutionInferenceEngine] 占位，接入模型后
/// 替换为真实实现（分块推理、后端自动检测等）。
abstract class SuperResolutionInferenceEngine {
  /// 模型是否已配置并可运行。
  bool get isReady;

  /// 引擎展示名。
  String get displayName;

  /// 把 [inputPath] 放大 [scale] 倍写入 [outputPath]（png）。
  /// 未就绪时抛 [InferenceNotReadyException]。
  Future<void> upscale({
    required String inputPath,
    required String outputPath,
    required int scale,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  });
}

/// 占位实现：报告未就绪，调用即抛 [InferenceNotReadyException]。
class NotConfiguredSuperResolutionInferenceEngine
    implements SuperResolutionInferenceEngine {
  const NotConfiguredSuperResolutionInferenceEngine();

  @override
  bool get isReady => false;

  @override
  String get displayName => 'ONNX Super Resolution';

  @override
  Future<void> upscale({
    required String inputPath,
    required String outputPath,
    required int scale,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) {
    throw const InferenceNotReadyException('onnx-super-resolution');
  }
}
