import 'package:jhentai/src/model/image_translation.dart';

import 'inference_exception.dart';
import 'inference_task.dart';

/// OCR 推理的结果，与 [RecognizedTextBlock] 的坐标系约定一致：
/// top-left 原点、原始正立（EXIF 应用后）图像空间的像素坐标。
class OcrInferenceResult {
  const OcrInferenceResult({
    required this.blocks,
    this.imageWidth,
    this.imageHeight,
  });

  final List<RecognizedTextBlock> blocks;

  /// 原始正立图像尺寸（若引擎能返回）；null 时由调用方用头部探针兜底。
  final int? imageWidth;
  final int? imageHeight;
}

/// 统一的 OCR 推理入口。当前实现：ONNX（PaddleOCR det+rec）。
/// 框架阶段由 [NotConfiguredOcrInferenceEngine] 占位，接入模型后替换为真实实现。
abstract class OcrInferenceEngine {
  /// 模型是否已配置并可运行（未下载 / 引擎未接入时为 false）。
  bool get isReady;

  /// 引擎展示名。
  String get displayName;

  /// 识别 [imagePath] 指向的图片，返回文本块。
  /// 未就绪时抛 [InferenceNotReadyException]。
  Future<OcrInferenceResult> recognize(
    String imagePath, {
    int maxDimension = 2200,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  });
}

/// 占位实现：报告未就绪，调用即抛 [InferenceNotReadyException]。
class NotConfiguredOcrInferenceEngine implements OcrInferenceEngine {
  const NotConfiguredOcrInferenceEngine();

  @override
  bool get isReady => false;

  @override
  String get displayName => 'ONNX OCR';

  @override
  Future<OcrInferenceResult> recognize(
    String imagePath, {
    int maxDimension = 2200,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) {
    throw const InferenceNotReadyException('onnx-ocr');
  }
}
