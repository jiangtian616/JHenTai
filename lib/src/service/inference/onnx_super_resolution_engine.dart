import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as image;

import 'inference_exception.dart';
import 'inference_task.dart';
import 'inference_safety.dart';
import 'onnx_ocr_engine.dart' show OnnxProviderResolver;
import 'onnx_runtime.dart';
import 'super_resolution_inference_engine.dart';

/// Immutable Real-ESRGAN model-file info, resolved on the UI isolate and passed
/// to the super-resolution worker isolate, which cannot touch [OnnxModelStore].
class OnnxSuperResolutionModelInfo {
  const OnnxSuperResolutionModelInfo({
    required this.modelPath,
    required this.fingerprint,
  });

  final String modelPath;
  final String fingerprint;
}

/// Tiled Real-ESRGAN anime x4 implementation.
///
/// Tiles overlap to provide convolution context, while only the central core is
/// copied to the destination. This prevents seams without retaining a whole
/// float output tensor for the page. The final RGBA canvas remains bounded by a
/// platform-specific pixel budget.
///
/// All work is performed on the calling isolate; the super-resolution worker
/// isolate owns an [OnnxRuntime] instance and drives this engine off the UI
/// thread.
class OnnxSuperResolutionInferenceEngine
    implements SuperResolutionInferenceEngine {
  OnnxSuperResolutionInferenceEngine({
    required this.runtime,
    required this.providerResolver,
    required this.model,
    this.safetyConfig,
  });

  final OnnxRuntime runtime;
  final OnnxProviderResolver providerResolver;
  final OnnxSuperResolutionModelInfo model;
  final InferenceSessionSafetyConfig? safetyConfig;

  static const int _modelScale = 4;
  static const int _tileCore = 128;
  static const int _tileOverlap = 12;
  static const int _maxInputBytes = 150 * 1024 * 1024;

  @override
  String get displayName => 'ONNX · Real-ESRGAN anime 6B';

  @override
  bool get isReady => runtime.isAvailable && providerResolver().isNotEmpty;

  @override
  Future<void> upscale({
    required String inputPath,
    required String outputPath,
    required int scale,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) async {
    final InferenceCancellationToken token =
        cancellationToken ?? InferenceCancellationToken();
    token.throwIfCancelled();
    if (scale != _modelScale) {
      throw ArgumentError.value(scale, 'scale', 'this model supports x4 only');
    }
    if (!isReady) {
      throw const InferenceNotReadyException('onnx-super-resolution');
    }
    final File sourceFile = File(inputPath);
    if (!await sourceFile.exists() ||
        await sourceFile.length() > _maxInputBytes) {
      throw StateError('super-resolution input is missing or exceeds 150 MiB');
    }
    final ort.OrtSession? session = await runtime.session(
      model.modelPath,
      modelFingerprint: model.fingerprint,
      providers: providerResolver(),
      safetyConfig: safetyConfig,
    );
    if (session == null) {
      throw const InferenceNotReadyException('onnx-super-resolution');
    }
    // Session creation (slow on first load) and the decode below are long
    // awaits with no checkpoint; honour a cancel that lands during setup so we
    // do not read + decode + allocate the output canvas only to discard it.
    token.throwIfCancelled();

    final image.Image? decoded = image.decodeImage(
      await sourceFile.readAsBytes(),
    );
    if (decoded == null) {
      throw StateError('unsupported super-resolution image');
    }
    final image.Image source = image.bakeOrientation(decoded);
    token.throwIfCancelled();
    final int outWidth = _checkedMultiply(source.width, scale);
    final int outHeight = _checkedMultiply(source.height, scale);
    final int outputPixels = _checkedMultiply(outWidth, outHeight);
    final int maxOutputPixels =
        (Platform.isAndroid || Platform.isIOS)
            ? 40 * 1024 * 1024
            : 100 * 1024 * 1024;
    if (outputPixels > maxOutputPixels) {
      throw StateError(
        'super-resolution output ${outWidth}x$outHeight exceeds the platform memory budget',
      );
    }
    final image.Image output = image.Image(
      width: outWidth,
      height: outHeight,
      numChannels: 4,
    );
    // The full output canvas (up to ~400 MB on desktop / ~160 MB on mobile) is
    // now allocated; abort here if the user cancelled during setup rather than
    // running every tile for a result nobody will keep.
    token.throwIfCancelled();

    final int tilesX = (source.width / _tileCore).ceil();
    final int tilesY = (source.height / _tileCore).ceil();
    final int totalTiles = tilesX * tilesY;
    int completedTiles = 0;
    for (int coreY = 0; coreY < source.height; coreY += _tileCore) {
      for (int coreX = 0; coreX < source.width; coreX += _tileCore) {
        token.throwIfCancelled();
        final int coreWidth = math.min(_tileCore, source.width - coreX);
        final int coreHeight = math.min(_tileCore, source.height - coreY);
        final int inputX = math.max(0, coreX - _tileOverlap);
        final int inputY = math.max(0, coreY - _tileOverlap);
        final int inputRight = math.min(
          source.width,
          coreX + coreWidth + _tileOverlap,
        );
        final int inputBottom = math.min(
          source.height,
          coreY + coreHeight + _tileOverlap,
        );
        final image.Image tile = image.copyCrop(
          source,
          x: inputX,
          y: inputY,
          width: inputRight - inputX,
          height: inputBottom - inputY,
        );
        final _TileOutput tileOutput = await _runTile(session, tile, token);
        final int cropOffsetX = (coreX - inputX) * scale;
        final int cropOffsetY = (coreY - inputY) * scale;
        _copyCore(
          tileOutput,
          output,
          sourceOffsetX: cropOffsetX,
          sourceOffsetY: cropOffsetY,
          destinationX: coreX * scale,
          destinationY: coreY * scale,
          width: coreWidth * scale,
          height: coreHeight * scale,
        );
        completedTiles++;
        onProgress?.call(completedTiles / totalTiles * 0.92);
      }
    }

    token.throwIfCancelled();
    final Uint8List png = image.encodePng(output, level: 6);
    token.throwIfCancelled();
    final File destination = File(outputPath);
    await destination.parent.create(recursive: true);
    final File temporary = File('$outputPath.aicore.tmp');
    try {
      await temporary.writeAsBytes(png, flush: true);
      token.throwIfCancelled();
      if (await destination.exists()) {
        await destination.delete();
      }
      await temporary.rename(destination.path);
      onProgress?.call(1);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<_TileOutput> _runTile(
    ort.OrtSession session,
    image.Image tile,
    InferenceCancellationToken token,
  ) async {
    final int pixels = _checkedMultiply(tile.width, tile.height);
    final Float32List input = Float32List(_checkedMultiply(pixels, 3));
    for (int y = 0; y < tile.height; y++) {
      for (int x = 0; x < tile.width; x++) {
        final image.Pixel pixel = tile.getPixel(x, y);
        final int index = y * tile.width + x;
        input[index] = pixel.rNormalized.toDouble();
        input[pixels + index] = pixel.gNormalized.toDouble();
        input[pixels * 2 + index] = pixel.bNormalized.toDouble();
      }
    }
    final ort.OrtValue inputTensor = await ort.OrtValue.fromList(input, <int>[
      1,
      3,
      tile.height,
      tile.width,
    ]);
    Map<String, ort.OrtValue>? outputs;
    try {
      token.throwIfCancelled();
      outputs = await runtime.run(session, <String, ort.OrtValue>{
        session.inputNames.first: inputTensor,
      });
      token.throwIfCancelled();
      final ort.OrtValue output = outputs[session.outputNames.first]!;
      final List<int> shape = output.shape;
      if (shape.length != 4 ||
          shape[0] != 1 ||
          shape[1] != 3 ||
          shape[2] != tile.height * _modelScale ||
          shape[3] != tile.width * _modelScale) {
        throw StateError('unexpected Real-ESRGAN output shape: $shape');
      }
      final int outPixels = _checkedMultiply(shape[2], shape[3]);
      final int elements = _checkedMultiply(outPixels, 3);
      if (elements > 8 * 1024 * 1024) {
        throw StateError('Real-ESRGAN tile exceeds tensor budget');
      }
      final List<dynamic> values = await output.asFlattenedList();
      if (values.length != elements) {
        throw StateError('Real-ESRGAN output data/shape mismatch');
      }
      return _TileOutput(shape[3], shape[2], values);
    } finally {
      if (outputs != null) {
        for (final ort.OrtValue value in outputs.values) {
          await value.dispose();
        }
      }
      await inputTensor.dispose();
    }
  }

  void _copyCore(
    _TileOutput source,
    image.Image destination, {
    required int sourceOffsetX,
    required int sourceOffsetY,
    required int destinationX,
    required int destinationY,
    required int width,
    required int height,
  }) {
    final int plane = source.width * source.height;
    for (int y = 0; y < height; y++) {
      final int sourceRow = (sourceOffsetY + y) * source.width;
      final int destinationRow = destinationY + y;
      for (int x = 0; x < width; x++) {
        final int sourceIndex = sourceRow + sourceOffsetX + x;
        destination.setPixelRgba(
          destinationX + x,
          destinationRow,
          _clamp255((source.values[sourceIndex] as num).toDouble() * 255),
          _clamp255(
            (source.values[plane + sourceIndex] as num).toDouble() * 255,
          ),
          _clamp255(
            (source.values[plane * 2 + sourceIndex] as num).toDouble() * 255,
          ),
          255,
        );
      }
    }
  }

  int _checkedMultiply(int left, int right) {
    if (left < 0 || right < 0 || (left != 0 && right > 0x7fffffff ~/ left)) {
      throw StateError('image dimensions overflow');
    }
    return left * right;
  }

  int _clamp255(double value) => value.isNaN ? 0 : value.round().clamp(0, 255);
}

class _TileOutput {
  const _TileOutput(this.width, this.height, this.values);

  final int width;
  final int height;
  final List<dynamic> values;
}
