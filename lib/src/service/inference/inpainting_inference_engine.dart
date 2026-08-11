import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as image;

import '../engine/engine_contract.dart';
import 'inference_exception.dart';
import 'inference_safety.dart';
import 'inference_task.dart';
import 'onnx_ocr_engine.dart' show OnnxProviderResolver;
import 'onnx_runtime.dart';

abstract class InpaintingInferenceEngine {
  String get displayName;
  bool get isReady;

  Future<void> inpaint({
    required String inputPath,
    required String outputPath,
    required List<PolygonMask> polygonMasks,
    InferenceCancellationToken? cancellationToken,
    void Function(double progress)? onProgress,
  });
}

class MiganOnnxModelInfo {
  const MiganOnnxModelInfo({
    required this.modelPath,
    required this.fingerprint,
  });

  final String? modelPath;
  final String fingerprint;
}

/// ONNX pipeline adapter for the verified ModelScope MI-GAN artifact.
///
/// The model accepts uint8 NCHW image/mask tensors and returns a uint8 NCHW
/// image. White in the input mask means known pixels and black means the
/// polygon area to repair, matching the upstream MI-GAN pipeline contract.
class MiganOnnxInpaintingInferenceEngine implements InpaintingInferenceEngine {
  MiganOnnxInpaintingInferenceEngine({
    required this.runtime,
    required this.providerResolver,
    required this.modelResolver,
    this.safetyConfig,
  });

  final OnnxRuntime runtime;
  final OnnxProviderResolver providerResolver;
  final MiganOnnxModelInfo Function() modelResolver;
  final InferenceSessionSafetyConfig? safetyConfig;

  static const String modelId = 'migan-pipeline-v2';
  static const int _maxInputBytes = 80 * 1024 * 1024;

  @override
  String get displayName => 'ONNX · MI-GAN Pipeline V2';

  MiganOnnxModelInfo get _model => modelResolver();

  @override
  bool get isReady {
    try {
      final MiganOnnxModelInfo model = _model;
      final String? path = model.modelPath;
      return runtime.isAvailable &&
          providerResolver().isNotEmpty &&
          model.fingerprint.isNotEmpty &&
          path != null &&
          File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> inpaint({
    required String inputPath,
    required String outputPath,
    required List<PolygonMask> polygonMasks,
    InferenceCancellationToken? cancellationToken,
    void Function(double progress)? onProgress,
  }) async {
    final InferenceCancellationToken token =
        cancellationToken ?? InferenceCancellationToken();
    token.throwIfCancelled();
    if (polygonMasks.isEmpty ||
        polygonMasks.any((PolygonMask mask) => !mask.isValid)) {
      throw StateError('inpainting requires valid polygon masks');
    }
    if (!isReady) {
      throw const InferenceNotReadyException(modelId);
    }

    final MiganOnnxModelInfo model = _model;
    final String modelPath = model.modelPath!;
    final File inputFile = File(inputPath);
    if (!await inputFile.exists() ||
        await inputFile.length() > _maxInputBytes) {
      throw StateError('inpainting input is missing or exceeds 80 MiB');
    }

    final Uint8List encoded = await inputFile.readAsBytes();
    token.throwIfCancelled();
    final image.Image? decoded = image.decodeImage(encoded);
    if (decoded == null) {
      throw StateError('unsupported inpainting image');
    }
    final image.Image source = image.bakeOrientation(decoded);
    final int maxPixels =
        Platform.isAndroid || Platform.isIOS
            ? 12 * 1024 * 1024
            : 24 * 1024 * 1024;
    if (source.width * source.height > maxPixels) {
      throw StateError(
        'inpainting image ${source.width}x${source.height} exceeds the '
        '$maxPixels pixel budget',
      );
    }
    final Uint8List mask = _rasterizePolygonMask(
      source.width,
      source.height,
      polygonMasks,
    );
    token.throwIfCancelled();
    onProgress?.call(0.12);

    final List<ort.OrtProvider> providers = providerResolver();
    final ort.OrtSession? session = await runtime.session(
      modelPath,
      modelFingerprint: model.fingerprint,
      providers: providers,
      safetyConfig: safetyConfig,
    );
    if (session == null) {
      throw const InferenceNotReadyException(modelId);
    }
    token.throwIfCancelled();
    onProgress?.call(0.25);

    final int pixels = source.width * source.height;
    final Uint8List imageInput = _toNchw(source);
    final ort.OrtValue imageTensor = await ort.OrtValue.fromList(
      imageInput,
      <int>[1, 3, source.height, source.width],
    );
    final ort.OrtValue maskTensor = await ort.OrtValue.fromList(mask, <int>[
      1,
      1,
      source.height,
      source.width,
    ]);
    Map<String, ort.OrtValue>? outputs;
    try {
      token.throwIfCancelled();
      outputs = await runtime.run(session, <String, ort.OrtValue>{
        'image': imageTensor,
        'mask': maskTensor,
      });
      token.throwIfCancelled();
      onProgress?.call(0.82);
      final ort.OrtValue? result =
          outputs['result'] ??
          (outputs.length == 1 ? outputs.values.first : null);
      if (result == null ||
          result.shape.length != 4 ||
          result.shape[0] != 1 ||
          result.shape[1] != 3 ||
          result.shape[2] != source.height ||
          result.shape[3] != source.width) {
        throw StateError('unexpected MI-GAN output shape: ${result?.shape}');
      }
      final List<dynamic> values = await result.asFlattenedList();
      if (values.length != pixels * 3) {
        throw StateError('MI-GAN output data/shape mismatch');
      }
      final image.Image repaired = _fromNchw(
        values,
        source.width,
        source.height,
      );
      final List<int> png = image.encodePng(repaired, level: 6);
      token.throwIfCancelled();
      await _writeAtomically(outputPath, png, token);
      onProgress?.call(1);
    } finally {
      if (outputs != null) {
        for (final ort.OrtValue output in outputs.values) {
          await output.dispose();
        }
      }
      await imageTensor.dispose();
      await maskTensor.dispose();
    }
  }

  Uint8List _toNchw(image.Image source) {
    final int pixels = source.width * source.height;
    final Uint8List result = Uint8List(pixels * 3);
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final image.Pixel pixel = source.getPixel(x, y);
        final int index = y * source.width + x;
        result[index] = _clamp(pixel.r);
        result[pixels + index] = _clamp(pixel.g);
        result[pixels * 2 + index] = _clamp(pixel.b);
      }
    }
    return result;
  }

  image.Image _fromNchw(List<dynamic> values, int width, int height) {
    final int plane = width * height;
    final image.Image result = image.Image(
      width: width,
      height: height,
      numChannels: 4,
    );
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        result.setPixelRgba(
          x,
          y,
          _clamp(values[index]),
          _clamp(values[plane + index]),
          _clamp(values[plane * 2 + index]),
          255,
        );
      }
    }
    return result;
  }

  Uint8List _rasterizePolygonMask(
    int width,
    int height,
    List<PolygonMask> polygons,
  ) {
    final Uint8List result = Uint8List.fromList(
      List<int>.filled(width * height, 255),
    );
    bool painted = false;
    for (final PolygonMask polygon in polygons) {
      final int left = math.max(0, polygon.left.floor());
      final int top = math.max(0, polygon.top.floor());
      final int right = math.min(width - 1, polygon.right.ceil());
      final int bottom = math.min(height - 1, polygon.bottom.ceil());
      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          if (_contains(polygon.points, x + 0.5, y + 0.5)) {
            result[y * width + x] = 0;
            painted = true;
          }
        }
      }
    }
    if (!painted) {
      throw StateError('polygon masks do not cover any source pixels');
    }
    return result;
  }

  bool _contains(List<EnginePoint> points, double x, double y) {
    bool inside = false;
    for (
      int index = 0, previous = points.length - 1;
      index < points.length;
      previous = index++
    ) {
      final EnginePoint current = points[index];
      final EnginePoint prior = points[previous];
      final bool crosses = (current.y > y) != (prior.y > y);
      if (crosses &&
          x <
              (prior.x - current.x) * (y - current.y) / (prior.y - current.y) +
                  current.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<void> _writeAtomically(
    String outputPath,
    List<int> bytes,
    InferenceCancellationToken token,
  ) async {
    final File destination = File(outputPath);
    final File temporary = File('$outputPath.migan.tmp');
    await destination.parent.create(recursive: true);
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      token.throwIfCancelled();
      if (await destination.exists()) {
        await destination.delete();
      }
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  int _clamp(Object value) =>
      (value is num ? value.toDouble() : 0).round().clamp(0, 255);
}
