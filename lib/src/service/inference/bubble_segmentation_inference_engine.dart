import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as img;

import '../engine/engine_contract.dart';
import 'inference_exception.dart';
import 'inference_safety.dart';
import 'inference_task.dart';
import 'onnx_ocr_engine.dart' show OnnxProviderResolver;
import 'onnx_runtime.dart';

class BubbleSegmentationModelInfo {
  const BubbleSegmentationModelInfo({
    required this.modelPath,
    required this.fingerprint,
  });

  final String? modelPath;
  final String fingerprint;
}

/// Runtime adapter for NeuronCState/manga109-segmentation-bubble-onnx.
///
/// The export is a static Ultralytics YOLO11-seg graph:
/// images [1,3,1600,1600] -> output0 [1,37,52500] and output1
/// [1,32,400,400]. The first four values are xywh, the fifth is the
/// single-class confidence, and the remaining 32 values are mask coefficients.
/// This detector exposes conservative source-image boxes to the OCR/layout
/// pipeline. It never exposes its full-bubble masks to the inpainting path.
class BubbleSegmentationInferenceEngine {
  BubbleSegmentationInferenceEngine({
    required this.runtime,
    required this.providerResolver,
    required this.modelResolver,
  });

  static const int inputSize = 1600;
  static const int candidateCount = 52500;
  static const int candidateChannels = 37;
  static const double confidenceThreshold = 0.5;
  static const double nmsThreshold = 0.55;

  final OnnxRuntime runtime;
  final OnnxProviderResolver providerResolver;
  final BubbleSegmentationModelInfo Function() modelResolver;

  bool get isReady {
    try {
      final BubbleSegmentationModelInfo model = modelResolver();
      return runtime.isAvailable &&
          providerResolver().isNotEmpty &&
          model.fingerprint.isNotEmpty &&
          model.modelPath != null &&
          File(model.modelPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<DetectionResult> detect(
    String imagePath, {
    required InferenceCancellationToken cancellationToken,
    void Function(double progress)? onProgress,
  }) async {
    cancellationToken.throwIfCancelled();
    if (!isReady) {
      throw const InferenceNotReadyException(
        'manga109-segmentation-bubble-onnx',
      );
    }
    final File file = File(imagePath);
    if (!await file.exists() || await file.length() > 80 * 1024 * 1024) {
      throw StateError('bubble segmentation input is missing or exceeds 80 MiB');
    }
    final img.Image? decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw StateError('unsupported bubble segmentation input image');
    }
    final img.Image source = img.bakeOrientation(decoded);
    final _Letterbox letterbox = _Letterbox.fromSource(source);
    final Float32List input = _toNchw(letterbox.image);
    onProgress?.call(0.16);

    final BubbleSegmentationModelInfo model = modelResolver();
    final ort.OrtSession? session = await runtime.session(
      model.modelPath!,
      modelFingerprint: model.fingerprint,
      providers: providerResolver(),
      safetyConfig: const InferenceSessionSafetyConfig(
        useArena: false,
        providerOptions: <String, Map<String, String>>{},
        sessionConfigEntries: <String, String>{
          'session.enable_cpu_mem_arena': '0',
        },
        requireStaticShapes: true,
        inputShape: <int>[1, 3, inputSize, inputSize],
        memoryBudgetBytes: 512 * 1024 * 1024,
        maxInputPixels: inputSize * inputSize,
      ),
      intraOpNumThreads: 2,
      interOpNumThreads: 1,
    );
    if (session == null) {
      throw const InferenceNotReadyException(
        'manga109-segmentation-bubble-onnx',
      );
    }
    final ort.OrtValue tensor = await ort.OrtValue.fromList(
      input,
      <int>[1, 3, inputSize, inputSize],
    );
    Map<String, ort.OrtValue>? outputs;
    try {
      cancellationToken.throwIfCancelled();
      outputs = await runtime.run(session, <String, ort.OrtValue>{
        'images': tensor,
      });
      cancellationToken.throwIfCancelled();
      final ort.OrtValue? raw = outputs['output0'] ??
          (outputs.length == 2 ? outputs.values.first : null);
      if (raw == null || !_sameShape(raw.shape, <int>[1, 37, 52500])) {
        throw StateError('unexpected bubble detector output: ${raw?.shape}');
      }
      final List<dynamic> values = await raw.asFlattenedList();
      if (values.length != candidateChannels * candidateCount) {
        throw StateError('unexpected bubble detector output length');
      }
      final List<_BubbleCandidate> candidates = <_BubbleCandidate>[];
      for (int index = 0; index < candidateCount; index++) {
        final double confidence =
            (values[4 * candidateCount + index] as num).toDouble();
        if (!confidence.isFinite || confidence < confidenceThreshold) {
          continue;
        }
        final double cx = (values[index] as num).toDouble();
        final double cy = (values[candidateCount + index] as num).toDouble();
        final double width =
            (values[2 * candidateCount + index] as num).toDouble();
        final double height =
            (values[3 * candidateCount + index] as num).toDouble();
        final Rect rect = _mapRect(
          cx - width / 2,
          cy - height / 2,
          cx + width / 2,
          cy + height / 2,
          letterbox,
          source.width,
          source.height,
        );
        if (rect.width < 12 || rect.height < 12) continue;
        candidates.add(_BubbleCandidate(rect: rect, confidence: confidence));
      }
      final List<_BubbleCandidate> selected = nms(
        candidates,
        threshold: nmsThreshold,
      );
      onProgress?.call(0.92);
      return DetectionResult(
        regions: selected
            .map(
              (_BubbleCandidate candidate) => DetectedTextRegion(
                left: candidate.rect.left,
                top: candidate.rect.top,
                width: candidate.rect.width,
                height: candidate.rect.height,
                confidence: candidate.confidence,
              ),
            )
            .toList(growable: false),
      );
    } finally {
      if (outputs != null) {
        for (final ort.OrtValue value in outputs.values) {
          await value.dispose();
        }
      }
      await tensor.dispose();
    }
  }

  static List<_BubbleCandidate> nms(
    List<_BubbleCandidate> candidates, {
    double threshold = nmsThreshold,
    int maxDetections = 128,
  }) {
    final List<_BubbleCandidate> remaining = [...candidates]
      ..sort(
        (_BubbleCandidate a, _BubbleCandidate b) =>
            b.confidence.compareTo(a.confidence),
      );
    final List<_BubbleCandidate> selected = <_BubbleCandidate>[];
    while (remaining.isNotEmpty && selected.length < maxDetections) {
      final _BubbleCandidate best = remaining.removeAt(0);
      selected.add(best);
      remaining.removeWhere(
        (_BubbleCandidate other) => _iou(best.rect, other.rect) > threshold,
      );
    }
    return selected;
  }

  static Float32List _toNchw(img.Image source) {
    const int plane = inputSize * inputSize;
    final Float32List result = Float32List(plane * 3);
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final img.Pixel pixel = source.getPixel(x, y);
        final int index = y * inputSize + x;
        result[index] = pixel.r.toDouble() / 255;
        result[plane + index] = pixel.g.toDouble() / 255;
        result[plane * 2 + index] = pixel.b.toDouble() / 255;
      }
    }
    return result;
  }

  static Rect _mapRect(
    double left,
    double top,
    double right,
    double bottom,
    _Letterbox letterbox,
    int sourceWidth,
    int sourceHeight,
  ) {
    final double x1 = ((left - letterbox.padX) / letterbox.scale)
        .clamp(0, sourceWidth.toDouble())
        .toDouble();
    final double y1 = ((top - letterbox.padY) / letterbox.scale)
        .clamp(0, sourceHeight.toDouble())
        .toDouble();
    final double x2 = ((right - letterbox.padX) / letterbox.scale)
        .clamp(0, sourceWidth.toDouble())
        .toDouble();
    final double y2 = ((bottom - letterbox.padY) / letterbox.scale)
        .clamp(0, sourceHeight.toDouble())
        .toDouble();
    return Rect.fromLTRB(math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2));
  }

  static double _iou(Rect a, Rect b) {
    final double left = math.max(a.left, b.left);
    final double top = math.max(a.top, b.top);
    final double right = math.min(a.right, b.right);
    final double bottom = math.min(a.bottom, b.bottom);
    final double intersection = math.max(0, right - left) * math.max(0, bottom - top);
    final double union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  static bool _sameShape(List<int> actual, List<int> expected) =>
      actual.length == expected.length &&
      List<int>.generate(actual.length, (int i) => actual[i] == expected[i] ? 1 : 0)
          .every((int value) => value == 1);
}

class _BubbleCandidate {
  const _BubbleCandidate({required this.rect, required this.confidence});

  final Rect rect;
  final double confidence;
}

class _Letterbox {
  const _Letterbox({
    required this.image,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final img.Image image;
  final double scale;
  final double padX;
  final double padY;

  factory _Letterbox.fromSource(img.Image source) {
    final double scale = math.min(
      BubbleSegmentationInferenceEngine.inputSize / source.width,
      BubbleSegmentationInferenceEngine.inputSize / source.height,
    );
    final int width = math.max(1, (source.width * scale).round());
    final int height = math.max(1, (source.height * scale).round());
    final img.Image resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final img.Image canvas = img.Image(
      width: BubbleSegmentationInferenceEngine.inputSize,
      height: BubbleSegmentationInferenceEngine.inputSize,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    final int padX = (BubbleSegmentationInferenceEngine.inputSize - width) ~/ 2;
    final int padY = (BubbleSegmentationInferenceEngine.inputSize - height) ~/ 2;
    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);
    return _Letterbox(
      image: canvas,
      scale: scale,
      padX: padX.toDouble(),
      padY: padY.toDouble(),
    );
  }
}
