import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:image/image.dart' as image;
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/oriented_rect.dart';

import 'inference_exception.dart';
import 'inference_task.dart';
import 'inference_safety.dart';
import 'ocr_inference_engine.dart';
import 'onnx_runtime.dart';

typedef OnnxProviderResolver = List<ort.OrtProvider> Function();

/// Immutable ONNX OCR model-file info. Resolved on the UI isolate and passed
/// to the OCR worker isolate, which cannot touch [OnnxModelStore] (its
/// [GetxController]/pathService wiring is only initialized on the UI isolate).
class OnnxOcrModelInfo {
  const OnnxOcrModelInfo({
    required this.detPath,
    required this.clsPath,
    required this.recPath,
    required this.dictPath,
    required this.fingerprint,
  });

  final String detPath;
  final String clsPath;
  final String recPath;
  final String dictPath;
  final String fingerprint;
}

/// End-to-end PP-OCRv6 small pipeline: DB detection, line orientation and CTC
/// recognition. The detector uses connected DB regions and conservative
/// rectangle expansion; this avoids native OpenCV while preserving original
/// image coordinates for the translation overlay.
///
/// All work is performed on the calling isolate; the OCR worker isolate owns
/// an [OnnxRuntime] instance and drives this engine off the UI thread.
class OnnxOcrInferenceEngine implements OcrInferenceEngine {
  OnnxOcrInferenceEngine({
    required this.runtime,
    required this.providerResolver,
    required this.model,
    this.safetyConfig,
  });

  final OnnxRuntime runtime;
  final OnnxProviderResolver providerResolver;
  final OnnxOcrModelInfo model;
  final InferenceSessionSafetyConfig? safetyConfig;

  static const double _detThreshold = 0.3;
  static const double _boxThreshold = 0.5;
  static const double _textThreshold = 0.5;
  static const int _maxInputBytes = 80 * 1024 * 1024;
  static const int _maxDetectedLines = 256;

  /// DB unclip ratio: expands each text box by `area * ratio / perimeter`
  /// along its own axes (matches RapidOCR's `unclip_ratio: 1.6`).
  static const double _unclipRatio = 1.6;

  /// Recognition crops are processed in width-sorted batches to amortize the
  /// ONNX call overhead; the rec model's dynamic-batch profile allows up to 6.
  static const int _recBatchSize = 6;

  @override
  String get displayName => 'ONNX · PP-OCRv6 small';

  @override
  bool get isReady => runtime.isAvailable && providerResolver().isNotEmpty;

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

    final List<ort.OrtProvider> providers = providerResolver();
    final List<ort.OrtSession?> sessions =
        await Future.wait(<Future<ort.OrtSession?>>[
          runtime.session(
            model.detPath,
            modelFingerprint: '${model.fingerprint}:det',
            providers: providers,
            safetyConfig: safetyConfig,
          ),
          runtime.session(
            model.clsPath,
            modelFingerprint: '${model.fingerprint}:cls',
            providers: providers,
            safetyConfig: safetyConfig,
          ),
          runtime.session(
            model.recPath,
            modelFingerprint: '${model.fingerprint}:rec',
            providers: providers,
            safetyConfig: safetyConfig,
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

    // Pass 1: straighten each detected box (min-area rect + unclip) into an
    // axis-aligned crop and run the 180-degree orientation classifier.
    final List<String> characters = await _loadCharacters(model.dictPath);
    final List<_DetectedBox> validBoxes = <_DetectedBox>[];
    final List<image.Image> crops = <image.Image>[];
    for (int i = 0; i < boxes.length; i++) {
      token.throwIfCancelled();
      final image.Image? crop = straightenOcrCrop(original, boxes[i].rect);
      if (crop == null) {
        continue;
      }
      crops.add(await _classifyAndRotate(clsSession, crop, token));
      validBoxes.add(boxes[i]);
      onProgress?.call(0.42 + 0.28 * (i + 1) / boxes.length);
    }
    if (crops.isEmpty) {
      return OcrInferenceResult(
        blocks: const <RecognizedTextBlock>[],
        imageWidth: originalWidth,
        imageHeight: originalHeight,
      );
    }

    // Pass 2: recognize all crops in width-sorted batches.
    final List<_RecognizedLine> lines = await _recognizeLines(
      recSession,
      crops,
      characters,
      token,
    );
    final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[];
    for (int i = 0; i < validBoxes.length; i++) {
      final _RecognizedLine line = lines[i];
      if (line.text.trim().isNotEmpty && line.confidence >= _textThreshold) {
        final (double left, double top, double width, double height) =
            validBoxes[i].rect.bbox;
        blocks.add(
          RecognizedTextBlock(
            text: line.text.trim(),
            confidence: line.confidence,
            left: left,
            top: top,
            width: width,
            height: height,
          ),
        );
      }
      onProgress?.call(0.70 + 0.30 * (i + 1) / validBoxes.length);
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
    final InferencePixelSize bounded = InferencePixelBudget(
      safetyConfig?.maxInputPixels ?? 4 * 1024 * 1024,
    ).fit(width, height, alignment: 32);
    return image.copyResize(
      source,
      width: bounded.width,
      height: bounded.height,
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
    final double sx = originalWidth / mapWidth;
    final double sy = originalHeight / mapHeight;
    for (int seed = 0; seed < mask.length; seed++) {
      if (mask[seed] == 0 || visited[seed] != 0) continue;
      token.throwIfCancelled();
      int head = 0;
      int tail = 0;
      queue[tail++] = seed;
      visited[seed] = 1;
      int count = 0;
      double scoreSum = 0;
      final List<OcrPoint> pixels = <OcrPoint>[];
      while (head < tail) {
        final int index = queue[head++];
        final int x = index % mapWidth;
        final int y = index ~/ mapWidth;
        pixels.add((x * sx, y * sy));
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
      final double score = scoreSum / math.max(1, count);
      if (count < 6 || score < _boxThreshold) {
        continue;
      }
      // Minimal-area oriented rect around the component — the text direction
      // and thickness — expanded by the DB unclip distance along its axes.
      final OrientedRect rect = unclipOrientedRect(
        minAreaRect(pixels),
        ratio: _unclipRatio,
      );
      final (double _, double _, double width, double height) = rect.bbox;
      if (width < 4 || height < 4) {
        continue;
      }
      result.add(_DetectedBox(rect, score));
    }

    result.sort((_DetectedBox a, _DetectedBox b) {
      final (double aLeft, double aTop, double aWidth, double aHeight) =
          a.rect.bbox;
      final (double bLeft, double bTop, double bWidth, double bHeight) =
          b.rect.bbox;
      final bool mostlyVertical =
          result.where((_DetectedBox box) {
            final (double _, double _, double width, double height) =
                box.rect.bbox;
            return height > width * 1.4;
          }).length >
          result.length / 2;
      if (mostlyVertical) {
        final int x = bLeft.compareTo(aLeft);
        return x != 0 ? x : aTop.compareTo(bTop);
      }
      final double dy = aTop - bTop;
      return dy.abs() < 10 ? aLeft.compareTo(bLeft) : aTop.compareTo(bTop);
    });
    return result.take(_maxDetectedLines).toList(growable: false);
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

  /// Recognizes [crops] with a single dynamic-batch ONNX call per group of
  /// similar-width lines (width-sorted so each batch's right-padding stays
  /// small), returning one [RecognizedLine] per crop in input order.
  Future<List<_RecognizedLine>> _recognizeLines(
    ort.OrtSession session,
    List<image.Image> crops,
    List<String> characters,
    InferenceCancellationToken token,
  ) async {
    final List<_RecognizedLine> results = List<_RecognizedLine>.filled(
      crops.length,
      const _RecognizedLine('', 0),
    );
    final List<int> order = List<int>.generate(crops.length, (int i) => i)
      ..sort((int a, int b) => crops[a].width.compareTo(crops[b].width));
    for (int start = 0; start < order.length; start += _recBatchSize) {
      token.throwIfCancelled();
      final List<int> batch = order.sublist(
        start,
        math.min(start + _recBatchSize, order.length),
      );
      int maxTargetWidth = 0;
      for (final int index in batch) {
        maxTargetWidth = math.max(
          maxTargetWidth,
          _recTargetWidth(crops[index]),
        );
      }
      final Float32List input = _normalizedBatchNchw(<image.Image>[
        for (final int index in batch) crops[index],
      ], maxTargetWidth);
      try {
        final _TensorOutput output = await _runOutput(
          session,
          input,
          <int>[batch.length, 3, 48, maxTargetWidth],
          token,
          expectedRank: 3,
        );
        final int timeSteps = output.shape[1];
        final int classes = output.shape[2];
        if (classes != characters.length ||
            output.values.length != batch.length * timeSteps * classes) {
          throw StateError(
            'PP-OCR dictionary/model mismatch: $classes != ${characters.length}',
          );
        }
        for (int j = 0; j < batch.length; j++) {
          results[batch[j]] = _ctcDecode(
            output.values,
            j,
            timeSteps,
            classes,
            characters,
          );
        }
      } catch (_) {
        // The exported model may not accept a dynamic batch dimension; fall
        // back to one inference call per line for this group.
        for (final int index in batch) {
          results[index] = await _recognizeSingle(
            session,
            crops[index],
            characters,
            token,
          );
        }
      }
    }
    return results;
  }

  /// Single-line recognition (batch of one), used as a fallback when a group's
  /// batched call fails — e.g. a model export with a fixed batch dimension.
  Future<_RecognizedLine> _recognizeSingle(
    ort.OrtSession session,
    image.Image crop,
    List<String> characters,
    InferenceCancellationToken token,
  ) async {
    final int targetWidth = _recTargetWidth(crop);
    final Float32List input = _normalizedPaddedNchw(crop, targetWidth, 48);
    final _TensorOutput output = await _runOutput(
      session,
      input,
      <int>[1, 3, 48, targetWidth],
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
    return _ctcDecode(output.values, 0, timeSteps, classes, characters);
  }

  /// The recognition input width for [crop]: height 48, width from the aspect
  /// ratio rounded up to a multiple of 8, bounded to [320, 2048].
  int _recTargetWidth(image.Image crop) {
    const int targetHeight = 48;
    final double ratio = crop.width / math.max(1, crop.height);
    final int targetWidth =
        (math.max(320, (targetHeight * ratio).ceil()) / 8).ceil() * 8;
    return targetWidth.clamp(320, 2048);
  }

  /// Greedy CTC decode of one batch row into text plus mean frame confidence.
  _RecognizedLine _ctcDecode(
    List<dynamic> values,
    int batchIndex,
    int timeSteps,
    int classes,
    List<String> characters,
  ) {
    final StringBuffer text = StringBuffer();
    int previous = -1;
    double confidence = 0;
    int selected = 0;
    final int row = batchIndex * timeSteps * classes;
    for (int t = 0; t < timeSteps; t++) {
      final int offset = row + t * classes;
      int bestIndex = 0;
      double bestScore = double.negativeInfinity;
      for (int c = 0; c < classes; c++) {
        final double score = (values[offset + c] as num).toDouble();
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

  /// Batch [C, H, W] normalization for recognition: every crop resized to
  /// height 48 at its own aspect-preserving width, then right-padded to
  /// [targetWidth] so the batch shares one dynamic-width input tensor.
  Float32List _normalizedBatchNchw(List<image.Image> crops, int targetWidth) {
    const int targetHeight = 48;
    final int pixels = targetHeight * targetWidth;
    final Float32List output = Float32List(crops.length * 3 * pixels);
    for (int b = 0; b < crops.length; b++) {
      final image.Image crop = crops[b];
      final double ratio = crop.width / math.max(1, crop.height);
      final int resizedWidth = math.min(
        targetWidth,
        math.max(1, (targetHeight * ratio).ceil()),
      );
      final image.Image resized = image.copyResize(
        crop,
        width: resizedWidth,
        height: targetHeight,
        interpolation: image.Interpolation.linear,
      );
      final int offset = b * 3 * pixels;
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < resizedWidth; x++) {
          final image.Pixel pixel = resized.getPixel(x, y);
          final int index = offset + y * targetWidth + x;
          output[index] = pixel.rNormalized * 2 - 1;
          output[pixels + index] = pixel.gNormalized * 2 - 1;
          output[2 * pixels + index] = pixel.bNormalized * 2 - 1;
        }
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
      outputs = await runtime.run(session, <String, ort.OrtValue>{
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
  const _DetectedBox(this.rect, this.detectionScore);

  /// The unclipped minimal-area oriented rect in original image coordinates.
  final OrientedRect rect;
  final double detectionScore;
}

class _RecognizedLine {
  const _RecognizedLine(this.text, this.confidence);

  final String text;
  final double confidence;
}

/// Straigtens a detected text box into an axis-aligned crop by rotating its
/// enclosing region around the box center so the text direction becomes
/// horizontal, then cropping the inner box. Slanted text that an axis-aligned
/// crop would feed to the recognizer on a tilt now arrives upright.
image.Image? straightenOcrCrop(image.Image source, OrientedRect rect) {
  const double margin = 8;
  final double cosA = math.cos(rect.angle);
  final double sinA = math.sin(rect.angle);
  final double hw = rect.width / 2;
  final double hh = rect.height / 2;
  // Axis-aligned half-extents of the rotated rect, plus margin so the
  // rotated corners stay inside the region.
  final double halfW = hw * cosA.abs() + hh * sinA.abs() + margin;
  final double halfH = hw * sinA.abs() + hh * cosA.abs() + margin;
  final int rx = math.max(0, (rect.cx - halfW).floor());
  final int ry = math.max(0, (rect.cy - halfH).floor());
  final int rw =
      math.min(source.width, (rect.cx + halfW).ceil()).clamp(1, source.width) -
      rx;
  final int rh =
      math
          .min(source.height, (rect.cy + halfH).ceil())
          .clamp(1, source.height) -
      ry;
  if (rw < 2 || rh < 2) {
    return null;
  }
  final image.Image region = image.copyCrop(
    source,
    x: rx,
    y: ry,
    width: rw,
    height: rh,
  );
  // image.copyRotate is clockwise for positive angles; rotating by -angle
  // aligns the rect's long axis (at `rect.angle`) with the horizontal.
  final image.Image rotated = image.copyRotate(
    region,
    angle: -rect.angle * 180 / math.pi,
  );
  // Where the rect center lands after rotation. copyRotate rotates around the
  // REGION's center and returns a larger canvas, so the output center is
  // (rotated.width/2, rotated.height/2) and the rect center's offset is
  // relative to the region center — the two differ once the region was clamped
  // to the image edge.
  final double ccx = rect.cx - rx;
  final double ccy = rect.cy - ry;
  final double rcx = rotated.width / 2.0;
  final double rcy = rotated.height / 2.0;
  final double relX = ccx - region.width / 2.0;
  final double relY = ccy - region.height / 2.0;
  final double cosN = math.cos(-rect.angle);
  final double sinN = math.sin(-rect.angle);
  final double nccx = rcx + relX * cosN + relY * sinN;
  final double nccy = rcy - relX * sinN + relY * cosN;
  final int cropX = (nccx - rect.width / 2).floor().clamp(0, rotated.width - 1);
  final int cropY = (nccy - rect.height / 2).floor().clamp(
    0,
    rotated.height - 1,
  );
  final int cropW = rect.width.ceil().clamp(1, rotated.width - cropX);
  final int cropH = rect.height.ceil().clamp(1, rotated.height - cropY);
  if (cropW < 2 || cropH < 2) {
    return null;
  }
  return image.copyCrop(
    rotated,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );
}
