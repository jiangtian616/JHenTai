import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as image;

import '../../utils/oriented_rect.dart';
import '../engine/ctd_engine_adapter.dart';
import '../engine/engine_contract.dart';
import 'ctd_model_evidence.dart';
import 'inference_exception.dart';
import 'inference_safety.dart';
import 'inference_task.dart';
import 'onnx_ocr_engine.dart' show OnnxProviderResolver;
import 'onnx_runtime.dart';

class CtdOnnxModelInfo {
  const CtdOnnxModelInfo({required this.modelPath, required this.fingerprint});

  final String? modelPath;
  final String fingerprint;
}

class CtdOnnxInferenceEngine {
  CtdOnnxInferenceEngine({
    required this.runtime,
    required this.providerResolver,
    required this.modelResolver,
  });

  static const int inputSize = 1024;
  static const double maskThreshold = 0.3;

  final OnnxRuntime runtime;
  final OnnxProviderResolver providerResolver;
  final CtdOnnxModelInfo Function() modelResolver;

  bool get isReady {
    try {
      final CtdOnnxModelInfo model = modelResolver();
      return runtime.isAvailable &&
          providerResolver().isNotEmpty &&
          model.fingerprint.isNotEmpty &&
          model.modelPath != null &&
          File(model.modelPath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<CtdDetectionOutput> detect(
    String imagePath, {
    required InferenceCancellationToken cancellationToken,
    void Function(double progress)? onProgress,
  }) async {
    cancellationToken.throwIfCancelled();
    if (!isReady) {
      throw const InferenceNotReadyException('comic-text-detector-beta-0.3');
    }
    final File sourceFile = File(imagePath);
    if (!await sourceFile.exists() || await sourceFile.length() > 80 << 20) {
      throw StateError('CTD input is missing or exceeds 80 MiB');
    }
    final image.Image? decoded = image.decodeImage(
      await sourceFile.readAsBytes(),
    );
    if (decoded == null) {
      throw StateError('unsupported CTD input image');
    }
    final image.Image source = image.bakeOrientation(decoded);
    cancellationToken.throwIfCancelled();
    onProgress?.call(0.08);

    final double scale = math.min(
      inputSize / source.width,
      inputSize / source.height,
    );
    final int activeWidth = math.max(1, (source.width * scale).round());
    final int activeHeight = math.max(1, (source.height * scale).round());
    final image.Image resized = image.copyResize(
      source,
      width: activeWidth,
      height: activeHeight,
      interpolation: image.Interpolation.linear,
    );
    final Float32List input = Float32List(3 * inputSize * inputSize);
    const int plane = inputSize * inputSize;
    for (int y = 0; y < activeHeight; y++) {
      cancellationToken.throwIfCancelled();
      for (int x = 0; x < activeWidth; x++) {
        final image.Pixel pixel = resized.getPixel(x, y);
        final int offset = y * inputSize + x;
        input[offset] = pixel.r.toDouble() / 255;
        input[plane + offset] = pixel.g.toDouble() / 255;
        input[plane * 2 + offset] = pixel.b.toDouble() / 255;
      }
    }
    onProgress?.call(0.2);

    final CtdOnnxModelInfo model = modelResolver();
    final List<ort.OrtProvider> providers = providerResolver();
    final ort.OrtSession? session = await runtime.session(
      model.modelPath!,
      modelFingerprint: model.fingerprint,
      providers: providers,
      safetyConfig: const InferenceSessionSafetyConfig(
        useArena: false,
        providerOptions: <String, Map<String, String>>{},
        sessionConfigEntries: <String, String>{
          'session.enable_cpu_mem_arena': '0',
        },
        requireStaticShapes: true,
        inputShape: CtdModelEvidence.inputShape,
        memoryBudgetBytes: 512 * 1024 * 1024,
        maxInputPixels: inputSize * inputSize,
      ),
      intraOpNumThreads: 2,
      interOpNumThreads: 1,
    );
    if (session == null) {
      throw const InferenceNotReadyException('comic-text-detector-beta-0.3');
    }
    final ort.OrtValue inputTensor = await ort.OrtValue.fromList(
      input,
      CtdModelEvidence.inputShape,
    );
    Map<String, ort.OrtValue>? outputs;
    try {
      cancellationToken.throwIfCancelled();
      onProgress?.call(0.3);
      outputs = await runtime.run(session, <String, ort.OrtValue>{
        CtdModelEvidence.inputName: inputTensor,
      });
      cancellationToken.throwIfCancelled();
      final ort.OrtValue? segmentation =
          outputs[CtdModelEvidence.segmentationOutputName];
      if (segmentation == null ||
          !_sameShape(
            segmentation.shape,
            CtdModelEvidence.segmentationOutputShape,
          )) {
        throw StateError(
          'unexpected CTD segmentation output: ${segmentation?.shape}',
        );
      }
      final List<dynamic> values = await segmentation.asFlattenedList();
      if (values.length != plane) {
        throw StateError('unexpected CTD segmentation length');
      }
      final Float32List probabilities = Float32List(plane);
      for (int index = 0; index < values.length; index++) {
        probabilities[index] = (values[index] as num).toDouble();
      }
      cancellationToken.throwIfCancelled();
      onProgress?.call(0.82);
      final List<PolygonMask> masks = ctdPolygonsFromSegmentation(
        probabilities: probabilities,
        mapWidth: inputSize,
        mapHeight: inputSize,
        activeWidth: activeWidth,
        activeHeight: activeHeight,
        sourceWidth: source.width,
        sourceHeight: source.height,
        threshold: maskThreshold,
      );
      onProgress?.call(1);
      return CtdDetectionOutput(polygonMasks: masks);
    } finally {
      if (outputs != null) {
        for (final ort.OrtValue value in outputs.values) {
          await value.dispose();
        }
      }
      await inputTensor.dispose();
    }
  }

  bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) {
      return false;
    }
    for (int index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) {
        return false;
      }
    }
    return true;
  }
}

/// Converts CTD's pixel segmentation into source-coordinate polygons without
/// substituting OCR rectangles. A small dilation joins adjacent glyph pixels;
/// each connected component keeps its own convex pixel boundary.
List<PolygonMask> ctdPolygonsFromSegmentation({
  required Float32List probabilities,
  required int mapWidth,
  required int mapHeight,
  required int activeWidth,
  required int activeHeight,
  required int sourceWidth,
  required int sourceHeight,
  double threshold = CtdOnnxInferenceEngine.maskThreshold,
  int dilationRadius = 2,
  int minimumPixels = 12,
  int maximumMasks = 512,
}) {
  if (mapWidth <= 0 ||
      mapHeight <= 0 ||
      activeWidth <= 0 ||
      activeHeight <= 0 ||
      activeWidth > mapWidth ||
      activeHeight > mapHeight ||
      sourceWidth <= 0 ||
      sourceHeight <= 0 ||
      probabilities.length != mapWidth * mapHeight) {
    throw ArgumentError('invalid CTD segmentation dimensions');
  }
  final Uint8List mask = Uint8List(probabilities.length);
  for (int y = 0; y < activeHeight; y++) {
    for (int x = 0; x < activeWidth; x++) {
      final int index = y * mapWidth + x;
      if (probabilities[index] <= threshold) {
        continue;
      }
      final int top = math.max(0, y - dilationRadius);
      final int bottom = math.min(activeHeight - 1, y + dilationRadius);
      final int left = math.max(0, x - dilationRadius);
      final int right = math.min(activeWidth - 1, x + dilationRadius);
      for (int ny = top; ny <= bottom; ny++) {
        final int row = ny * mapWidth;
        for (int nx = left; nx <= right; nx++) {
          mask[row + nx] = 1;
        }
      }
    }
  }

  final Uint8List visited = Uint8List(mask.length);
  final Int32List queue = Int32List(activeWidth * activeHeight);
  final List<({PolygonMask mask, int pixels})> components =
      <({PolygonMask mask, int pixels})>[];
  final double sx = sourceWidth / activeWidth;
  final double sy = sourceHeight / activeHeight;
  for (int y = 0; y < activeHeight; y++) {
    for (int x = 0; x < activeWidth; x++) {
      final int seed = y * mapWidth + x;
      if (mask[seed] == 0 || visited[seed] != 0) {
        continue;
      }
      int head = 0;
      int tail = 0;
      int pixelCount = 0;
      double scoreSum = 0;
      final List<OcrPoint> boundary = <OcrPoint>[];
      queue[tail++] = seed;
      visited[seed] = 1;
      while (head < tail) {
        final int index = queue[head++];
        final int cx = index % mapWidth;
        final int cy = index ~/ mapWidth;
        pixelCount++;
        scoreSum += probabilities[index];
        bool isBoundary = false;
        for (int dy = -1; dy <= 1; dy++) {
          final int ny = cy + dy;
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) {
              continue;
            }
            final int nx = cx + dx;
            if (nx < 0 || nx >= activeWidth || ny < 0 || ny >= activeHeight) {
              isBoundary = true;
              continue;
            }
            final int next = ny * mapWidth + nx;
            if (mask[next] == 0) {
              isBoundary = true;
            } else if (visited[next] == 0) {
              visited[next] = 1;
              queue[tail++] = next;
            }
          }
        }
        if (isBoundary) {
          boundary.add((cx * sx, cy * sy));
        }
      }
      if (pixelCount < minimumPixels || boundary.length < 3) {
        continue;
      }
      final List<OcrPoint> hull = convexHull(boundary);
      if (hull.length < 3) {
        continue;
      }
      final double confidence = (scoreSum / pixelCount).clamp(0, 1);
      final PolygonMask polygon = PolygonMask(
        points: hull
            .map(
              (OcrPoint point) => EnginePoint(
                x: point.$1.clamp(0, sourceWidth.toDouble()),
                y: point.$2.clamp(0, sourceHeight.toDouble()),
              ),
            )
            .toList(growable: false),
        confidence: confidence,
      );
      if (polygon.isValid) {
        components.add((mask: polygon, pixels: pixelCount));
      }
    }
  }
  components.sort((a, b) => b.pixels.compareTo(a.pixels));
  return components
      .take(maximumMasks)
      .map((component) => component.mask)
      .toList(growable: false);
}
