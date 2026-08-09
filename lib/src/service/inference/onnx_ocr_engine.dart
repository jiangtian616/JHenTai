import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as image;
import 'package:jhentai/src/model/image_translation.dart';

import 'inference_exception.dart';
import 'inference_task.dart';
import 'ocr_inference_engine.dart';
import 'onnx_model_store.dart';
import 'onnx_runtime.dart';

typedef OnnxProviderResolver = List<ort.OrtProvider> Function();

/// End-to-end PP-OCRv6 small pipeline: DB detection, line orientation and CTC
/// recognition. The detector uses connected DB regions and conservative
/// rectangle expansion; this avoids native OpenCV while preserving original
/// image coordinates for the translation overlay.
class OnnxOcrInferenceEngine implements OcrInferenceEngine {
  OnnxOcrInferenceEngine({required this.providerResolver});

  final OnnxProviderResolver providerResolver;

  static const double _detThreshold = 0.3;
  static const double _boxThreshold = 0.5;
  static const double _textThreshold = 0.5;
  static const int _maxInputBytes = 80 * 1024 * 1024;
  static const int _maxDetectedLines = 256;

  @override
  String get displayName => 'ONNX · PP-OCRv6 small';

  @override
  bool get isReady =>
      OnnxRuntime.instance.isAvailable &&
      providerResolver().isNotEmpty &&
      OnnxModelStore.instance.isManifestDownloaded(
        OnnxModelStore.ocrManifestId,
      );

  @override
  Future<OcrInferenceResult> recognize(
    String imagePath, {
    int maxDimension = 2200,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) async {
    final InferenceCancellationToken token =
        cancellationToken ?? InferenceCancellationToken();
    token.throwIfCancelled();
    if (!isReady) {
      throw const InferenceNotReadyException('onnx-ocr');
    }
    final File inputFile = File(imagePath);
    if (!await inputFile.exists() ||
        await inputFile.length() > _maxInputBytes) {
      throw StateError('OCR input is missing or exceeds 80 MiB');
    }

    final Map<String, String>? files = OnnxModelStore.instance
        .manifestFilePaths(OnnxModelStore.ocrManifestId);
    final String? fingerprint = OnnxModelStore.instance.fingerprintOf(
      OnnxModelStore.ocrManifestId,
    );
    if (files == null || fingerprint == null) {
      throw const InferenceNotReadyException('onnx-ocr');
    }
    final List<ort.OrtProvider> providers = providerResolver();
    final List<ort.OrtSession?> sessions =
        await Future.wait(<Future<ort.OrtSession?>>[
          OnnxRuntime.instance.session(
            files['det']!,
            modelFingerprint: '$fingerprint:det',
            providers: providers,
          ),
          OnnxRuntime.instance.session(
            files['cls']!,
            modelFingerprint: '$fingerprint:cls',
            providers: providers,
          ),
          OnnxRuntime.instance.session(
            files['rec']!,
            modelFingerprint: '$fingerprint:rec',
            providers: providers,
          ),
        ]);
    final ort.OrtSession? detSession = sessions[0];
    final ort.OrtSession? clsSession = sessions[1];
    final ort.OrtSession? recSession = sessions[2];
    if (detSession == null || clsSession == null || recSession == null) {
      throw const InferenceNotReadyException('onnx-ocr');
    }

    final image.Image? decoded = image.decodeImage(
      await inputFile.readAsBytes(),
    );
    if (decoded == null) {
      throw StateError('unsupported OCR image');
    }
    final image.Image original = image.bakeOrientation(decoded);
    final int originalWidth = original.width;
    final int originalHeight = original.height;
    final image.Image working = _resizeForDetection(original, maxDimension);
    onProgress?.call(0.08);

    token.throwIfCancelled();
    final List<_DetectedBox> boxes = await _detect(
      detSession,
      working,
      originalWidth,
      originalHeight,
      token,
    );
    onProgress?.call(0.42);
    if (boxes.isEmpty) {
      return OcrInferenceResult(
        blocks: const <RecognizedTextBlock>[],
        imageWidth: originalWidth,
        imageHeight: originalHeight,
      );
    }

    final List<String> characters = await _loadCharacters(files['dict']!);
    final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[];
    for (int i = 0; i < boxes.length; i++) {
      token.throwIfCancelled();
      final _DetectedBox box = boxes[i];
      image.Image crop = _cropForRecognition(original, box);
      crop = await _classifyAndRotate(clsSession, crop, token);
      final _RecognizedLine line = await _recognizeLine(
        recSession,
        crop,
        characters,
        token,
      );
      if (line.text.trim().isNotEmpty && line.confidence >= _textThreshold) {
        blocks.add(
          RecognizedTextBlock(
            text: line.text.trim(),
            confidence: line.confidence,
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
          ),
        );
      }
      onProgress?.call(0.42 + 0.58 * (i + 1) / boxes.length);
    }

    return OcrInferenceResult(
      blocks: blocks,
      imageWidth: originalWidth,
      imageHeight: originalHeight,
    );
  }

  image.Image _resizeForDetection(image.Image source, int maxDimension) {
    final int safeMax = maxDimension.clamp(640, 2600);
    double scale = math.min(1, safeMax / math.max(source.width, source.height));
    int width = math.max(32, (source.width * scale / 32).round() * 32);
    int height = math.max(32, (source.height * scale / 32).round() * 32);
    width = math.min(width, 2624);
    height = math.min(height, 2624);
    return image.copyResize(
      source,
      width: width,
      height: height,
      interpolation: image.Interpolation.linear,
    );
  }

  Future<List<_DetectedBox>> _detect(
    ort.OrtSession session,
    image.Image working,
    int originalWidth,
    int originalHeight,
    InferenceCancellationToken token,
  ) async {
    final Float32List input = _normalizedNchw(
      working,
      working.width,
      working.height,
    );
    final List<dynamic> output = await _runSingleOutput(
      session,
      input,
      <int>[1, 3, working.height, working.width],
      token,
      expectedRank: 4,
      expectedChannels: 1,
    );
    final int mapWidth = working.width;
    final int mapHeight = working.height;
    if (output.length != mapWidth * mapHeight) {
      throw StateError(
        'unexpected PP-OCR detector output: ${output.length} != ${mapWidth * mapHeight}',
      );
    }
    final Uint8List mask = Uint8List(output.length);
    for (int y = 0; y < mapHeight; y++) {
      final int row = y * mapWidth;
      for (int x = 0; x < mapWidth; x++) {
        final int index = row + x;
        if ((output[index] as num).toDouble() <= _detThreshold) {
          continue;
        }
        mask[index] = 1;
        if (x + 1 < mapWidth) mask[index + 1] = 1;
        if (y + 1 < mapHeight) mask[index + mapWidth] = 1;
        if (x + 1 < mapWidth && y + 1 < mapHeight) {
          mask[index + mapWidth + 1] = 1;
        }
      }
    }

    final Uint8List visited = Uint8List(mask.length);
    final Int32List queue = Int32List(mask.length);
    final List<_DetectedBox> result = <_DetectedBox>[];
    for (int seed = 0; seed < mask.length; seed++) {
      if (mask[seed] == 0 || visited[seed] != 0) continue;
      token.throwIfCancelled();
      int head = 0;
      int tail = 0;
      queue[tail++] = seed;
      visited[seed] = 1;
      int minX = mapWidth;
      int minY = mapHeight;
      int maxX = 0;
      int maxY = 0;
      int count = 0;
      double scoreSum = 0;
      while (head < tail) {
        final int index = queue[head++];
        final int x = index % mapWidth;
        final int y = index ~/ mapWidth;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        scoreSum += (output[index] as num).toDouble();
        count++;
        for (int dy = -1; dy <= 1; dy++) {
          final int ny = y + dy;
          if (ny < 0 || ny >= mapHeight) continue;
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final int nx = x + dx;
            if (nx < 0 || nx >= mapWidth) continue;
            final int next = ny * mapWidth + nx;
            if (mask[next] != 0 && visited[next] == 0) {
              visited[next] = 1;
              queue[tail++] = next;
            }
          }
        }
      }
      final int width = maxX - minX + 1;
      final int height = maxY - minY + 1;
      final double score = scoreSum / math.max(1, count);
      if (count < 6 || width < 4 || height < 4 || score < _boxThreshold) {
        continue;
      }
      final double expand =
          width * height * 1.6 / math.max(1, 2 * (width + height));
      final double sx = originalWidth / mapWidth;
      final double sy = originalHeight / mapHeight;
      final double left = math.max(0, (minX - expand) * sx);
      final double top = math.max(0, (minY - expand) * sy);
      final double right = math.min(
        originalWidth.toDouble(),
        (maxX + expand) * sx,
      );
      final double bottom = math.min(
        originalHeight.toDouble(),
        (maxY + expand) * sy,
      );
      if (right - left >= 4 && bottom - top >= 4) {
        result.add(_DetectedBox(left, top, right - left, bottom - top, score));
      }
    }

    result.sort((_DetectedBox a, _DetectedBox b) {
      final bool mostlyVertical =
          result
              .where((_DetectedBox box) => box.height > box.width * 1.4)
              .length >
          result.length / 2;
      if (mostlyVertical) {
        final int x = b.left.compareTo(a.left);
        return x != 0 ? x : a.top.compareTo(b.top);
      }
      final double dy = a.top - b.top;
      return dy.abs() < 10 ? a.left.compareTo(b.left) : a.top.compareTo(b.top);
    });
    return result.take(_maxDetectedLines).toList(growable: false);
  }

  image.Image _cropForRecognition(image.Image source, _DetectedBox box) {
    final int x = box.left.floor().clamp(0, source.width - 1);
    final int y = box.top.floor().clamp(0, source.height - 1);
    final int width = box.width.ceil().clamp(1, source.width - x);
    final int height = box.height.ceil().clamp(1, source.height - y);
    image.Image crop = image.copyCrop(
      source,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    if (crop.height / crop.width >= 1.5) {
      crop = image.copyRotate(crop, angle: 90);
    }
    return crop;
  }

  Future<image.Image> _classifyAndRotate(
    ort.OrtSession session,
    image.Image crop,
    InferenceCancellationToken token,
  ) async {
    const int targetHeight = 48;
    const int targetWidth = 192;
    final Float32List input = _normalizedPaddedNchw(
      crop,
      targetWidth,
      targetHeight,
    );
    final List<dynamic> output = await _runSingleOutput(
      session,
      input,
      const <int>[1, 3, targetHeight, targetWidth],
      token,
      expectedRank: 2,
    );
    if (output.length != 2) {
      throw StateError('unexpected PP-OCR classifier output');
    }
    final double upright = (output[0] as num).toDouble();
    final double rotated = (output[1] as num).toDouble();
    return rotated > upright && rotated > 0.9
        ? image.copyRotate(crop, angle: 180)
        : crop;
  }

  Future<_RecognizedLine> _recognizeLine(
    ort.OrtSession session,
    image.Image crop,
    List<String> characters,
    InferenceCancellationToken token,
  ) async {
    const int targetHeight = 48;
    final double ratio = crop.width / math.max(1, crop.height);
    final int targetWidth =
        (math.max(320, (targetHeight * ratio).ceil()) / 8).ceil() * 8;
    final int safeWidth = targetWidth.clamp(320, 2048);
    final Float32List input = _normalizedPaddedNchw(
      crop,
      safeWidth,
      targetHeight,
    );
    final _TensorOutput output = await _runOutput(
      session,
      input,
      <int>[1, 3, targetHeight, safeWidth],
      token,
      expectedRank: 3,
    );
    final int timeSteps = output.shape[1];
    final int classes = output.shape[2];
    if (classes != characters.length ||
        output.values.length != timeSteps * classes) {
      throw StateError(
        'PP-OCR dictionary/model mismatch: $classes != ${characters.length}',
      );
    }
    final StringBuffer text = StringBuffer();
    int previous = -1;
    double confidence = 0;
    int selected = 0;
    for (int t = 0; t < timeSteps; t++) {
      final int offset = t * classes;
      int bestIndex = 0;
      double bestScore = double.negativeInfinity;
      for (int c = 0; c < classes; c++) {
        final double score = (output.values[offset + c] as num).toDouble();
        if (score > bestScore) {
          bestScore = score;
          bestIndex = c;
        }
      }
      if (bestIndex != 0 && bestIndex != previous) {
        text.write(characters[bestIndex]);
        confidence += bestScore;
        selected++;
      }
      previous = bestIndex;
    }
    return _RecognizedLine(
      text.toString(),
      selected == 0 ? 0 : confidence / selected,
    );
  }

  Future<List<String>> _loadCharacters(String path) async {
    final List<String> dictionary = await File(path).readAsLines();
    return <String>['blank', ...dictionary, ' '];
  }

  Float32List _normalizedNchw(image.Image source, int width, int height) {
    final Float32List output = Float32List(width * height * 3);
    final int pixels = width * height;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final image.Pixel pixel = source.getPixel(x, y);
        final int index = y * width + x;
        output[index] = pixel.rNormalized * 2 - 1;
        output[pixels + index] = pixel.gNormalized * 2 - 1;
        output[pixels * 2 + index] = pixel.bNormalized * 2 - 1;
      }
    }
    return output;
  }

  Float32List _normalizedPaddedNchw(image.Image source, int width, int height) {
    final double ratio = source.width / math.max(1, source.height);
    final int resizedWidth = math.min(
      width,
      math.max(1, (height * ratio).ceil()),
    );
    final image.Image resized = image.copyResize(
      source,
      width: resizedWidth,
      height: height,
      interpolation: image.Interpolation.linear,
    );
    final Float32List output = Float32List(width * height * 3);
    final int pixels = width * height;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < resizedWidth; x++) {
        final image.Pixel pixel = resized.getPixel(x, y);
        final int index = y * width + x;
        output[index] = pixel.rNormalized * 2 - 1;
        output[pixels + index] = pixel.gNormalized * 2 - 1;
        output[pixels * 2 + index] = pixel.bNormalized * 2 - 1;
      }
    }
    return output;
  }

  Future<List<dynamic>> _runSingleOutput(
    ort.OrtSession session,
    Float32List input,
    List<int> shape,
    InferenceCancellationToken token, {
    required int expectedRank,
    int? expectedChannels,
  }) async =>
      (await _runOutput(
        session,
        input,
        shape,
        token,
        expectedRank: expectedRank,
        expectedChannels: expectedChannels,
      )).values;

  Future<_TensorOutput> _runOutput(
    ort.OrtSession session,
    Float32List input,
    List<int> shape,
    InferenceCancellationToken token, {
    required int expectedRank,
    int? expectedChannels,
  }) async {
    token.throwIfCancelled();
    final ort.OrtValue tensor = await ort.OrtValue.fromList(input, shape);
    Map<String, ort.OrtValue>? outputs;
    try {
      final String inputName = session.inputNames.first;
      outputs = await OnnxRuntime.instance.run(session, <String, ort.OrtValue>{
        inputName: tensor,
      });
      token.throwIfCancelled();
      final ort.OrtValue output = outputs[session.outputNames.first]!;
      if (output.shape.length != expectedRank ||
          output.shape.any((int dimension) => dimension <= 0) ||
          (expectedChannels != null && output.shape[1] != expectedChannels)) {
        throw StateError('unexpected ONNX output shape: ${output.shape}');
      }
      final int elements = output.shape.fold<int>(
        1,
        (int product, int dimension) => product * dimension,
      );
      if (elements > 64 * 1024 * 1024) {
        throw StateError('OCR output exceeds tensor budget');
      }
      final List<dynamic> values = await output.asFlattenedList();
      if (values.length != elements) {
        throw StateError('ONNX output data/shape mismatch');
      }
      return _TensorOutput(output.shape, values);
    } finally {
      if (outputs != null) {
        for (final ort.OrtValue output in outputs.values) {
          await output.dispose();
        }
      }
      await tensor.dispose();
    }
  }
}

class _TensorOutput {
  const _TensorOutput(this.shape, this.values);

  final List<int> shape;
  final List<dynamic> values;
}

class _DetectedBox {
  const _DetectedBox(
    this.left,
    this.top,
    this.width,
    this.height,
    this.detectionScore,
  );

  final double left;
  final double top;
  final double width;
  final double height;
  final double detectionScore;
}

class _RecognizedLine {
  const _RecognizedLine(this.text, this.confidence);

  final String text;
  final double confidence;
}
