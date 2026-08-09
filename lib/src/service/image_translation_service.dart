import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';

import '../model/image_translation.dart';
import '../setting/image_translation_setting.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

ImageTranslationService imageTranslationService = ImageTranslationService();

/// Result of the recognition step. `imageWidth`/`imageHeight` are the upright
/// (orientation-applied) pixel dimensions for engines that provide them (Apple
/// Live Text), so the overlay scales blocks in the same space the image is
/// actually displayed in. Tesseract/Paddle return null and the caller falls
/// back to its header-based dimension probe.
typedef _RecognizeResult = ({
  List<RecognizedTextBlock> blocks,
  int? imageWidth,
  int? imageHeight,
});

class ImageTranslationService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String taskIdPrefix = 'imageTranslation';
  static const String paddlePrepareId = 'paddlePrepare';
  static const String ocrModelDownloadIdPrefix = 'ocrModelDownload';
  static const String batchProgressId = 'imageTranslationBatchProgress';
  static const String liveTextOcrChannelName =
      'top.jtmonster.jhentai.live_text_ocr';

  final Map<String, ImageTranslationResult> _results = {};
  final Set<String> _downloadingOcrModels = {};
  final Map<String, double?> _ocrModelDownloadProgress = {};
  static const String paddleOcrVlRepo = 'PaddlePaddle/PaddleOCR-VL-1.6';

  /// Paddle runtime preparation state, kept in the service so it survives
  /// leaving the settings page.
  bool preparingPaddle = false;
  String? paddleStage;
  final List<String> _paddleOutput = [];

  List<String> get paddleOutput => List.unmodifiable(_paddleOutput);

  /// Batch translation progress shown by the read-page top banner.
  bool isBatchTranslating = false;
  int batchTotal = 0;
  int batchCompleted = 0;
  ImageTranslationStage currentStage = ImageTranslationStage.idle;
  bool _cancelRequested = false;
  Process? _activeProcess;
  CancelToken? _activeCancelToken;

  /// Apple Live Text OCR (Vision framework) is exposed over a platform channel
  /// registered natively in ios/Runner and macos/Runner.
  late final MethodChannel _liveTextChannel =
      MethodChannel(liveTextOcrChannelName);

  void beginBatch(int total) {
    _cancelRequested = false;
    isBatchTranslating = true;
    batchTotal = total;
    batchCompleted = 0;
    currentStage = ImageTranslationStage.idle;
    update([batchProgressId]);
  }

  void endBatch() {
    isBatchTranslating = false;
    batchCompleted = batchTotal;
    currentStage = ImageTranslationStage.done;
    _cancelRequested = false;
    update([batchProgressId]);
  }

  void cancelBatch() {
    _cancelRequested = true;
    _activeProcess?.kill();
    _activeProcess = null;
    _activeCancelToken?.cancel();
    _activeCancelToken = null;
    update([batchProgressId]);
  }

  bool get isCancelRequested => _cancelRequested;

  void _setStage(ImageTranslationStage stage) {
    currentStage = stage;
    update([batchProgressId]);
  }

  /// Whether the PaddleOCR venv has the paddleocr package installed.
  bool get isPaddleRuntimeInstalled {
    if (!File(_paddlePython).existsSync()) {
      return false;
    }
    final Directory libDir = Directory(join(_paddleVenv.path, 'lib'));
    if (!libDir.existsSync()) {
      return false;
    }
    for (final FileSystemEntity entity in libDir.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final File marker =
          File(join(entity.path, 'site-packages', 'paddleocr', '__init__.py'));
      if (marker.existsSync()) {
        return true;
      }
    }
    return false;
  }

  Future<void> deletePaddleRuntime() async {
    if (_paddleRoot.existsSync()) {
      await _paddleRoot.delete(recursive: true);
    }
    preparingPaddle = false;
    paddleStage = null;
    _paddleOutput.clear();
    update([paddlePrepareId]);
  }

  Directory get _paddleRoot =>
      Directory(join(pathService.jhOcrModelDir.path, 'paddleocr'));

  Directory get _paddleVenv => Directory(join(_paddleRoot.path, 'venv'));

  Directory get _paddleHuggingFaceCache =>
      Directory(join(_paddleRoot.path, 'huggingface'));

  String get _paddlePython => Platform.isWindows
      ? join(_paddleVenv.path, 'Scripts', 'python.exe')
      : join(_paddleVenv.path, 'bin', 'python');

  String taskId(String cacheKey) => '$taskIdPrefix::$cacheKey';

  String ocrModelDownloadId(String languageCode) =>
      '$ocrModelDownloadIdPrefix::$languageCode';

  bool isDownloadingOcrModel(String languageCode) =>
      _downloadingOcrModels.contains(languageCode);

  double? ocrModelDownloadProgress(String languageCode) =>
      _ocrModelDownloadProgress[languageCode];

  Directory get _translationCacheDirectory =>
      Directory(join(pathService.jhOcrModelDir.path, 'cache'));

  ImageTranslationResult resultFor(String cacheKey) =>
      _results[cacheKey] ?? const ImageTranslationResult.idle();

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..add(imageTranslationSetting);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> translate(ImageTranslationRequest request,
      {bool force = false}) async {
    final ImageTranslationResult existing = resultFor(request.cacheKey);
    if (!force &&
        (existing.status == ImageTranslationStatus.recognizing ||
            existing.status == ImageTranslationStatus.translating ||
            existing.status == ImageTranslationStatus.success)) {
      return;
    }

    _set(
        request.cacheKey,
        const ImageTranslationResult(
            status: ImageTranslationStatus.recognizing));
    _setStage(ImageTranslationStage.recognizing);

    String? temporaryPath;
    try {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      // Read the image bytes exactly once: they feed the persistent-cache
      // hash, the dimension probe and (for bytes-based requests) the OCR
      // subprocess file. Previously the file was read again inside
      // _persistentCacheKey and a just-written temporary file was read back.
      final List<int> sourceBytes = request.imageBytes == null
          ? await File(request.imagePath!).readAsBytes()
          : request.imageBytes!;

      final String persistentKey = _persistentCacheKey(request, sourceBytes);
      final ImageTranslationResult? cached =
          await _readPersistentResult(persistentKey);
      if (!force && cached != null) {
        _set(request.cacheKey, cached.copyWith(fromCache: true));
        return;
      }

      // The OCR subprocess needs a real file path; only bytes-based requests
      // materialize one, and only once a translation is actually about to run.
      final String imagePath;
      if (request.imagePath != null) {
        imagePath = request.imagePath!;
      } else {
        final String fileName =
            'image_translation_${sha256.convert(sourceBytes).toString()}.png';
        final File temporaryFile =
            File(join(pathService.tempDir.path, fileName));
        await temporaryFile.writeAsBytes(sourceBytes, flush: true);
        temporaryPath = temporaryFile.path;
        imagePath = temporaryFile.path;
      }

      // Probe the encoded dimensions from the image header only; the full
      // pixel decode happens inside the OCR engine subprocess.
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
          Uint8List.fromList(sourceBytes));
      final ui.ImageDescriptor descriptor =
          await ui.ImageDescriptor.encoded(buffer);
      final int probeWidth = descriptor.width;
      final int probeHeight = descriptor.height;
      descriptor.dispose();
      buffer.dispose();

      final _RecognizeResult recognized = await _recognize(imagePath);
      final List<RecognizedTextBlock> blocks = recognized.blocks;
      // Apple Live Text reports the upright (EXIF-applied) dimensions, which
      // the header probe misses; use them so the overlay scales blocks in the
      // same space the image is actually displayed in.
      final int imageWidth = recognized.imageWidth ?? probeWidth;
      final int imageHeight = recognized.imageHeight ?? probeHeight;
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      final String sourceText = blocks
          .map((block) => block.text)
          .where((text) => text.isNotEmpty)
          .join('\n');
      if (sourceText.isEmpty) {
        throw const ImageTranslationException('NO_TEXT');
      }

      if (!imageTranslationSetting.usesAppleOnDeviceTranslation &&
          !imageTranslationSetting.isTranslatorConfigured) {
        _set(
          request.cacheKey,
          ImageTranslationResult(
            status: ImageTranslationStatus.failed,
            sourceText: sourceText,
            blocks: blocks,
            errorMessage: 'TRANSLATOR_NOT_CONFIGURED',
            needsConfiguration: true,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ),
        );
        return;
      }

      _set(
        request.cacheKey,
        ImageTranslationResult(
            status: ImageTranslationStatus.translating,
            sourceText: sourceText,
            blocks: blocks,
            imageWidth: imageWidth,
            imageHeight: imageHeight),
      );
      await _writePersistentResult(persistentKey, resultFor(request.cacheKey));
      _setStage(ImageTranslationStage.translating);
      final String translatedText =
          imageTranslationSetting.usesAppleOnDeviceTranslation
              ? await _translateWithApple(sourceText)
              : await _translate(sourceText);
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      _setStage(ImageTranslationStage.masking);
      await Future.delayed(const Duration(milliseconds: 80));
      _setStage(ImageTranslationStage.embedding);
      await Future.delayed(const Duration(milliseconds: 80));
      _set(
        request.cacheKey,
        ImageTranslationResult(
            status: ImageTranslationStatus.success,
            sourceText: sourceText,
            translatedText: translatedText,
            blocks: blocks,
            imageWidth: imageWidth,
            imageHeight: imageHeight),
      );
      await _writePersistentResult(persistentKey, resultFor(request.cacheKey));
      _setStage(ImageTranslationStage.done);
    } on ImageTranslationException catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      log.warning('Image translation failed: ${e.code}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed, errorMessage: e.code));
      log.trace(stack);
    } on ProcessException catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      log.warning('Image OCR executable is unavailable: ${e.executable}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed,
              errorMessage: 'OCR_UNAVAILABLE'));
      log.trace(stack);
    } on DioException catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      log.warning('Image translation request failed: ${e.message}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed,
              errorMessage: 'TRANSLATION_REQUEST_FAILED'));
      log.trace(stack);
    } catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return;
      }
      log.error('Image translation failed', e, stack);
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed,
              errorMessage: 'TRANSLATION_FAILED'));
    } finally {
      if (temporaryPath != null) {
        File(temporaryPath).delete().ignore();
      }
    }
  }

  void _removeResult(String cacheKey) {
    _results.remove(cacheKey);
    update([taskId(cacheKey)]);
  }

  String _persistentCacheKey(
      ImageTranslationRequest request, List<int> imageBytes) {
    final String imageHash = sha256.convert(imageBytes).toString();
    final String configFingerprint = jsonEncode({
      'ocrEngine': imageTranslationSetting.ocrEngine.value.name,
      'ocrLanguage': imageTranslationSetting.ocrLanguage.value,
      'paddleLanguage': imageTranslationSetting.paddleOcrLanguage.value,
      'appleLanguage': imageTranslationSetting.appleLiveTextLanguage.value,
      'appleUseApi': imageTranslationSetting.appleLiveTextUseThirdPartyApi.value,
      'provider': imageTranslationSetting.translatorProvider.value.name,
      'endpoint': imageTranslationSetting.translatorEndpoint.value,
      'model': imageTranslationSetting.translatorModel.value,
      'target': imageTranslationSetting.targetLanguage.value,
      'promptVersion': 1,
    });
    return sha256
        .convert(utf8.encode('$imageHash:$configFingerprint'))
        .toString();
  }

  Future<ImageTranslationResult?> _readPersistentResult(String key) async {
    final File cacheFile =
        File(join(_translationCacheDirectory.path, '$key.json'));
    if (!await cacheFile.exists()) return null;
    try {
      final dynamic content = jsonDecode(utf8.decode(await compute(
          _decompressJson, await cacheFile.readAsBytes())));
      if (content is! Map) return null;
      final ImageTranslationResult result =
          ImageTranslationResult.successFromJson(
              Map<String, dynamic>.from(content));
      final String cleaned = _stripReasoning(result.translatedText);
      return cleaned.isEmpty ? null : result.copyWith(translatedText: cleaned);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentResult(
      String key, ImageTranslationResult result) async {
    await _translationCacheDirectory.create(recursive: true);
    final File cacheFile =
        File(join(_translationCacheDirectory.path, '$key.json'));
    // gzip-compress off the UI isolate so batch translation never blocks it.
    await cacheFile.writeAsBytes(
        await compute(_compressJson, jsonEncode(result.toJson())),
        flush: true);
  }

  /// Compresses persistent-translation JSON with gzip on a background isolate
  /// via [compute] (see [_writePersistentResult]).
  static Uint8List _compressJson(String content) =>
      Uint8List.fromList(gzip.encode(utf8.encode(content)));

  /// Decompresses persistent-translation JSON; falls back to the raw bytes for
  /// backward compatibility with cache files written before gzip compression.
  static Uint8List _decompressJson(Uint8List data) {
    try {
      return Uint8List.fromList(gzip.decode(data));
    } on FormatException {
      return data;
    }
  }

  Future<_RecognizeResult> _recognize(String imagePath) async {
    if (imageTranslationSetting.ocrEngine.value ==
        ImageOcrEngine.appleLiveText) {
      return _recognizeWithAppleLiveText(imagePath);
    }
    if (imageTranslationSetting.ocrEngine.value == ImageOcrEngine.paddleOcr ||
        imageTranslationSetting.ocrEngine.value ==
            ImageOcrEngine.paddleOcrVl16) {
      final List<RecognizedTextBlock> blocks =
          await _recognizeWithPaddleOcr(imagePath);
      return (blocks: blocks, imageWidth: null, imageHeight: null);
    }
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }

    final Map<String, String> environment = <String, String>{};
    final String? dataDirectory =
        imageTranslationSetting.ocrDataDirectory.value;
    if (dataDirectory != null && dataDirectory.isNotEmpty) {
      environment['TESSDATA_PREFIX'] = dataDirectory;
    }
    final Process process = await Process.start(
      imageTranslationSetting.ocrExecutable.value,
      [
        imagePath,
        'stdout',
        '-l',
        imageTranslationSetting.ocrLanguage.value,
        'tsv'
      ],
      environment: environment.isEmpty ? null : environment,
    );
    _activeProcess = process;
    final List<String> outputs = await Future.wait([
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
    ]);
    final String stdout = outputs[0];
    final String stderr = outputs[1];
    final int exitCode = await process.exitCode;
    _activeProcess = null;
    if (exitCode != 0) {
      log.warning('Tesseract exited with $exitCode: $stderr');
      throw const ImageTranslationException('OCR_FAILED');
    }

    final Map<String, _TesseractLine> lines = {};
    for (final String rawLine in const LineSplitter().convert(stdout)) {
      final List<String> fields = rawLine.split('\t');
      if (fields.length != 12 ||
          fields.first == 'level' ||
          fields[11].trim().isEmpty) {
        continue;
      }
      final int level = int.tryParse(fields[0]) ?? 0;
      if (level != 5) {
        continue;
      }
      final String key = '${fields[1]}:${fields[2]}:${fields[3]}:${fields[4]}';
      lines.putIfAbsent(key, _TesseractLine.new).add(
          fields[11].trim(),
          double.tryParse(fields[10]) ?? 0,
          double.tryParse(fields[6]) ?? 0,
          double.tryParse(fields[7]) ?? 0,
          double.tryParse(fields[8]) ?? 0,
          double.tryParse(fields[9]) ?? 0);
    }
    return (
      blocks: lines.values
          .map((line) => line.toBlock())
          .where((block) => block.text.isNotEmpty)
          .toList(),
      imageWidth: null,
      imageHeight: null,
    );
  }

  /// On-device OCR through Apple's Vision framework (Live Text). The native
  /// side runs VNRecognizeTextRequest off the main thread and returns text
  /// lines as top-left-origin pixel rectangles in the original upright image
  /// space, matching the [RecognizedTextBlock] convention. It also returns the
  /// upright pixel dimensions, which the caller must use for overlay scaling:
  /// the header-based dimension probe does not apply EXIF orientation, so on
  /// rotated pages it disagrees with the block coordinate space.
  Future<_RecognizeResult> _recognizeWithAppleLiveText(
      String imagePath) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }
    try {
      final Map<dynamic, dynamic>? response =
          await _liveTextChannel.invokeMethod<Map<dynamic, dynamic>>(
        'recognizeText',
        {
          'path': imagePath,
          'languages': _appleLiveTextLanguages(),
          'automaticallyDetectsLanguage':
              imageTranslationSetting.appleLiveTextLanguage.value == 'auto',
          'recognitionLevel': 'accurate',
          'maxDimension': 2200,
        },
      );
      if (response == null) {
        throw const ImageTranslationException('OCR_FAILED');
      }
      final List<dynamic> rawLines =
          response['lines'] as List<dynamic>? ?? const [];
      final List<RecognizedTextBlock> blocks = rawLines
          .whereType<Map>()
          .map((raw) => _appleLiveTextBlock(Map<String, dynamic>.from(raw)))
          .where((block) => block.text.trim().isNotEmpty)
          .toList();
      if (blocks.isEmpty) {
        throw const ImageTranslationException('NO_TEXT');
      }
      return (
        blocks: blocks,
        imageWidth: (response['width'] as num?)?.toInt(),
        imageHeight: (response['height'] as num?)?.toInt(),
      );
    } on ImageTranslationException {
      rethrow;
    } catch (e, stack) {
      log.warning('Apple Live Text OCR failed: $e');
      log.trace(stack);
      throw const ImageTranslationException('OCR_FAILED');
    }
  }

  /// Comma-separated BCP-47 codes from the Apple Live Text setting, or null to
  /// let Vision auto-detect among its supported languages.
  List<String>? _appleLiveTextLanguages() {
    final String value = imageTranslationSetting.appleLiveTextLanguage.value;
    if (value.trim().isEmpty || value.trim() == 'auto') {
      return null;
    }
    final List<String> languages = value
        .split(',')
        .map((language) => language.trim())
        .where((language) => language.isNotEmpty)
        .toList();
    return languages.isEmpty ? null : languages;
  }

  RecognizedTextBlock _appleLiveTextBlock(Map<String, dynamic> raw) =>
      RecognizedTextBlock(
        text: raw['text'] as String? ?? '',
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
        left: (raw['left'] as num?)?.toDouble() ?? 0,
        top: (raw['top'] as num?)?.toDouble() ?? 0,
        width: (raw['width'] as num?)?.toDouble() ?? 0,
        height: (raw['height'] as num?)?.toDouble() ?? 0,
      );

  Future<List<RecognizedTextBlock>> _recognizeWithPaddleOcr(
      String imagePath) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }
    if (!await File(_paddlePython).exists()) {
      throw const ImageTranslationException('PADDLE_RUNTIME_NOT_READY');
    }
    final bool useVl =
        imageTranslationSetting.ocrEngine.value == ImageOcrEngine.paddleOcrVl16;
    final String script = useVl
        ? """import json
from paddleocr import PaddleOCRVL
pipeline = PaddleOCRVL(pipeline_version='v1.6')
for result in pipeline.predict(r'''$imagePath'''):
 print(json.dumps(result.json, ensure_ascii=False))
"""
        : """import json
from paddleocr import PaddleOCR
language = '${imageTranslationSetting.paddleOcrLanguage.value}'
pipeline = PaddleOCR(
    lang=language,
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=language in ('japan', 'chinese_cht', 'korean'),
)
for result in pipeline.predict(r'''$imagePath'''):
 print(json.dumps(result.json, ensure_ascii=False))
""";
    final Process process = await Process.start(_paddlePython, [
      '-c',
      script
    ], environment: {
      'HF_HOME': _paddleHuggingFaceCache.path,
      'PADDLEX_HOME': _paddleRoot.path,
      'PADDLE_PDX_MODEL_SOURCE': 'huggingface',
      'PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK': 'True',
      // Hugging Face's Xet transport can stall on some domestic networks.
      // The normal HTTP path is more reliable for an in-app model download.
      'HF_HUB_DISABLE_XET': '1',
    });
    _activeProcess = process;
    final List<String> outputs = await Future.wait([
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
    ]);
    final String stdout = outputs[0];
    final String stderr = outputs[1];
    final int exitCode = await process.exitCode;
    _activeProcess = null;
    if (exitCode != 0) {
      log.warning('PaddleOCR exited with $exitCode: $stderr');
      throw const ImageTranslationException('OCR_FAILED');
    }
    final List<RecognizedTextBlock> blocks = _paddleBlocks(stdout);
    if (blocks.isEmpty) throw const ImageTranslationException('NO_TEXT');
    return blocks;
  }

  List<RecognizedTextBlock> _paddleBlocks(String output) {
    final List<RecognizedTextBlock> blocks = [];
    final RegExp jsonObject = RegExp(r'\{[\s\S]*\}');
    final Match? match = jsonObject.firstMatch(output);
    if (match == null) return blocks;
    try {
      final dynamic value = jsonDecode(match.group(0)!);
      _collectPaddleTexts(value, blocks);
    } catch (_) {
      return blocks;
    }
    return blocks;
  }

  void _collectPaddleTexts(dynamic value, List<RecognizedTextBlock> blocks) {
    if (value is Map) {
      final dynamic texts = value['rec_texts'] ?? value['rec_text'];
      final dynamic scores = value['rec_scores'] ?? value['rec_score'];
      final dynamic boxes = value['rec_boxes'];
      if (texts is List) {
        for (int index = 0; index < texts.length; index++) {
          final dynamic text = texts[index];
          if (text is String && text.trim().isNotEmpty) {
            final dynamic score =
                scores is List && index < scores.length ? scores[index] : 0;
            blocks.add(_paddleBlock(
                text.trim(),
                (score as num?)?.toDouble() ?? 0,
                boxes is List && index < boxes.length ? boxes[index] : null));
          }
        }
      } else if (texts is String && texts.trim().isNotEmpty) {
        blocks.add(_paddleBlock(
            texts.trim(), (scores as num?)?.toDouble() ?? 0, null));
      }
      for (final dynamic child in value.values) {
        if (child != texts && child != scores)
          _collectPaddleTexts(child, blocks);
      }
    } else if (value is List) {
      for (final dynamic child in value) {
        _collectPaddleTexts(child, blocks);
      }
    }
  }

  RecognizedTextBlock _paddleBlock(
      String text, double confidence, dynamic box) {
    if (box is List && box.length >= 4) {
      final List<double> values =
          box.take(4).map((value) => (value as num?)?.toDouble() ?? 0).toList();
      return RecognizedTextBlock(
          text: text,
          confidence: confidence,
          left: values[0],
          top: values[1],
          width: values[2] - values[0],
          height: values[3] - values[1]);
    }
    return RecognizedTextBlock(text: text, confidence: confidence);
  }

  Future<File> exportOverlay(ImageTranslationRequest request) async {
    final ImageTranslationResult result = resultFor(request.cacheKey);
    final List<String> translations = const LineSplitter()
        .convert(result.translatedText)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final List<RecognizedTextBlock> blocks = result.blocks
        .where((block) => block.width > 4 && block.height > 4)
        .toList();
    if (result.status != ImageTranslationStatus.success ||
        translations.length != blocks.length) {
      throw const ImageTranslationException('OVERLAY_NOT_READY');
    }
    final Uint8List source = Uint8List.fromList(
        request.imageBytes ?? await File(request.imagePath!).readAsBytes());
    final ui.Codec codec = await ui.instantiateImageCodec(source);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..drawImage(frame.image, Offset.zero, Paint());
    for (int index = 0; index < blocks.length; index++) {
      _paintTranslation(canvas, blocks[index], translations[index]);
    }
    final ui.Image image = await recorder
        .endRecording()
        .toImage(frame.image.width, frame.image.height);
    final int width = frame.image.width;
    final int height = frame.image.height;
    // ui.Image cannot cross isolate boundaries, so rasterization (drawImage +
    // toImage, GPU-backed Canvas work) must stay on the UI isolate. The cheap
    // raw-RGBA copy happens here as well; the expensive PNG compression runs
    // on a background isolate so large exports don't jank the UI.
    final ByteData? raw =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    image.dispose();
    if (raw == null)
      throw const ImageTranslationException('OVERLAY_ENCODE_FAILED');
    final Uint8List pngBytes = await compute<
        (Uint8List rgba, int width, int height),
        Uint8List>(_encodePngOverlay,
        (raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes), width, height));
    final Directory directory =
        Directory(join(pathService.jhOcrModelDir.path, 'overlays'));
    await directory.create(recursive: true);
    final File output = File(join(directory.path,
        'translation_${sha256.convert(source).toString().substring(0, 16)}.png'));
    await output.writeAsBytes(pngBytes, flush: true);
    return output;
  }

  /// PNG-encodes raw RGBA pixels on a background isolate (see [exportOverlay]).
  /// The payload is a (rgba, width, height) record; input and output are plain
  /// byte lists so they can cross the isolate boundary. Implements the minimal
  /// PNG container by hand (signature + IHDR + zlib-compressed IDAT + IEND) to
  /// avoid pulling a codec package into the dependency graph.
  static Uint8List _encodePngOverlay(
      (Uint8List rgba, int width, int height) payload) {
    final (Uint8List rgba, int width, int height) = payload;
    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final ByteData ihdr = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 6) // color type: truecolor with alpha
      ..setUint8(10, 0) // compression: deflate
      ..setUint8(11, 0) // filter method
      ..setUint8(12, 0); // interlace: none
    _addPngChunk(builder, 'IHDR', ihdr.buffer.asUint8List());

    // Each scanline is prefixed with filter type 0 (None) and the whole
    // payload is zlib-compressed (the format PNG requires for IDAT).
    final int stride = width * 4;
    final Uint8List scanlines = Uint8List(rgba.length + height);
    int src = 0;
    int dst = 0;
    for (int y = 0; y < height; y++) {
      scanlines[dst++] = 0;
      for (int x = 0; x < stride; x++) {
        scanlines[dst++] = rgba[src++];
      }
    }
    _addPngChunk(builder, 'IDAT', zlib.encode(scanlines));
    _addPngChunk(builder, 'IEND', const []);
    return builder.takeBytes();
  }

  static void _addPngChunk(
      BytesBuilder builder, String type, List<int> data) {
    final Uint8List typeBytes = ascii.encode(type);
    final Uint8List chunk = Uint8List(typeBytes.length + data.length)
      ..setRange(0, typeBytes.length, typeBytes)
      ..setRange(typeBytes.length, typeBytes.length + data.length, data);
    final ByteData length = ByteData(4)..setUint32(0, data.length);
    final ByteData crc = ByteData(4)..setUint32(0, _pngCrc32(chunk));
    builder.add(length.buffer.asUint8List());
    builder.add(chunk);
    builder.add(crc.buffer.asUint8List());
  }

  static int _pngCrc32(List<int> data) {
    const int polynomial = 0xEDB88320;
    int crc = 0xFFFFFFFF;
    for (final int byte in data) {
      crc ^= byte;
      for (int bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ polynomial : crc >> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  void _paintTranslation(
      Canvas canvas, RecognizedTextBlock block, String translation) {
    final Rect rect = Rect.fromLTWH(
        block.left - 4, block.top - 3, block.width + 8, block.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = Colors.white);
    final double fontSize = (rect.width / (translation.length * 0.82))
        .clamp(8, (rect.height * 0.6).clamp(10, 30))
        .toDouble();
    final TextPainter painter = TextPainter(
        text: TextSpan(
            text: translation,
            style: TextStyle(
                color: Colors.black, fontSize: fontSize, height: 1.05)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…')
      ..layout(maxWidth: rect.width - 4);
    painter.paint(
        canvas, Offset(rect.left + 2, rect.center.dy - painter.height / 2));
  }

  /// On-device translation through Apple's Translation framework. Only used in
  /// Apple Live Text mode with the third-party API toggle off; on systems that
  /// do not support it the native side reports TRANSLATION_UNAVAILABLE.
  ///
  /// The source text is split into its lines and translated one-for-one so the
  /// read-page overlay keeps a 1:1 mapping between recognized blocks and
  /// translated lines (translating the whole page as a single blob would merge
  /// or drop lines, misaligning the boxes and losing dialogue).
  Future<String> _translateWithApple(String sourceText) async {
    try {
      final List<String> sourceLines =
          const LineSplitter().convert(sourceText);
      final Map<dynamic, dynamic>? response =
          await _liveTextChannel.invokeMethod<Map<dynamic, dynamic>>(
        'translateText',
        {
          'lines': sourceLines,
          'target': _appleTargetLanguage(),
          'source': _appleSourceLanguage(),
        },
      );
      final List<dynamic> rawLines =
          response?['lines'] as List<dynamic>? ?? const [];
      final List<String> translatedLines = rawLines
          .map((line) => line?.toString() ?? '')
          .toList();
      if (translatedLines.join('\n').trim().isEmpty) {
        throw const ImageTranslationException('TRANSLATION_FAILED');
      }
      return translatedLines.join('\n');
    } on PlatformException catch (e) {
      if (e.code == 'TRANSLATION_UNAVAILABLE') {
        throw const ImageTranslationException('TRANSLATION_UNAVAILABLE');
      }
      if (e.code == 'TRANSLATION_NOT_INSTALLED') {
        log.warning('Apple on-device translation language pack missing: ${e.details}');
        throw const ImageTranslationException('TRANSLATION_NOT_INSTALLED');
      }
      log.warning('Apple on-device translation failed: ${e.code} ${e.message}');
      throw const ImageTranslationException('TRANSLATION_FAILED');
    } on ImageTranslationException {
      rethrow;
    } catch (e, stack) {
      log.warning('Apple on-device translation failed: $e');
      log.trace(stack);
      throw const ImageTranslationException('TRANSLATION_FAILED');
    }
  }

  // ---------------------------------------------------------------------------
  // Gallery title / comment auto-translation (Apple on-device only)
  // ---------------------------------------------------------------------------

  static const int maxGalleryTextCacheEntries = 2000;
  static const int _galleryTextConcurrency = 4;

  /// LRU cache (insertion-ordered map) keyed by [String _galleryTextKey].
  final Map<String, String> _galleryTextCache = {};
  /// Keys whose translation failed this session, so a visible burst of titles
  /// does not retry the same unavailable text on every rebuild.
  final Set<String> _galleryTextFailed = {};
  final Map<String, Completer<String>> _galleryTextCompleters = {};
  final List<Future<void> Function()> _galleryTextQueue = [];
  int _galleryTextActive = 0;
  Timer? _galleryTextSaveTimer;

  /// Single in-flight cache load, shared by concurrent callers so the first
  /// visible burst waits for the persisted entries instead of re-translating.
  Future<void>? _galleryTextCacheLoadFuture;

  File get _galleryTextCacheFile =>
      File(join(_translationCacheDirectory.path, 'gallery_text_cache.json'));

  bool get _galleryTextEnabled =>
      (Platform.isIOS || Platform.isMacOS) &&
      imageTranslationSetting.autoTranslateGalleryText.value &&
      imageTranslationSetting.usesAppleOnDeviceTranslation;

  String _galleryTextKey(String text) => sha256
      .convert(utf8.encode(jsonEncode({
        'text': text,
        'target': imageTranslationSetting.targetLanguage.value,
        'source': imageTranslationSetting.appleLiveTextLanguage.value,
      })))
      .toString();

  /// The current translation of [text] if cached, or null when the feature is
  /// off or the text has not been translated yet. Synchronous so widgets can
  /// read the cache directly in build.
  String? galleryTextTranslationFor(String text) {
    if (!_galleryTextEnabled) return null;
    return _galleryTextCache[_galleryTextKey(text)];
  }

  /// Translates a gallery title or a comment text run on-device, returning
  /// [text] unchanged when the feature is disabled, unavailable, or the native
  /// translation fails — callers can always render the returned string. A
  /// modest worker queue keeps bursts of visible titles from spawning parallel
  /// TranslationSessions, and in-flight requests share one Future per key.
  Future<String> translateGalleryText(String text) async {
    if (!_galleryTextEnabled) return text;
    if (text.trim().isEmpty) return text;
    final String key = _galleryTextKey(text);
    // Fast paths so cached, failed, or in-flight texts never occupy a queue
    // slot or hit the native translation again.
    final String? cached = _galleryTextCache[key];
    if (cached != null) return cached;
    if (_galleryTextFailed.contains(key)) return text;
    final Completer<String>? existing = _galleryTextCompleters[key];
    if (existing != null) {
      return existing.future;
    }
    final Completer<String> completer = Completer<String>();
    _galleryTextCompleters[key] = completer;
    _enqueueGalleryTextTranslation(
        () => _runGalleryTextTranslation(key, text, completer));
    return completer.future;
  }

  void _enqueueGalleryTextTranslation(Future<void> Function() task) {
    _galleryTextQueue.add(task);
    _pumpGalleryTextQueue();
  }

  void _pumpGalleryTextQueue() {
    while (_galleryTextActive < _galleryTextConcurrency &&
        _galleryTextQueue.isNotEmpty) {
      final Future<void> Function() task = _galleryTextQueue.removeAt(0);
      _galleryTextActive++;
      task().whenComplete(() {
        _galleryTextActive--;
        _pumpGalleryTextQueue();
      });
    }
  }

  Future<void> _runGalleryTextTranslation(
      String key, String text, Completer<String> completer) async {
    String result = text;
    try {
      await _ensureGalleryTextCacheLoaded();
      final String? cached = _galleryTextCache[key];
      if (cached != null) {
        result = cached;
      } else if (!_galleryTextFailed.contains(key)) {
        final String translated = await _translateWithApple(text);
        if (translated.trim().isNotEmpty) {
          result = translated;
          _galleryTextCache[key] = translated;
          _evictGalleryTextCache();
          _scheduleGalleryTextCacheSave();
        }
      }
    } on ImageTranslationException {
      _galleryTextFailed.add(key);
    } on Exception {
      _galleryTextFailed.add(key);
    } finally {
      _galleryTextCompleters.remove(key);
      if (!completer.isCompleted) completer.complete(result);
    }
  }

  void _evictGalleryTextCache() {
    while (_galleryTextCache.length > maxGalleryTextCacheEntries) {
      _galleryTextCache.remove(_galleryTextCache.keys.first);
    }
  }

  Future<void> _ensureGalleryTextCacheLoaded() =>
      _galleryTextCacheLoadFuture ??= _loadGalleryTextCache();

  Future<void> _loadGalleryTextCache() async {
    try {
      if (!await _galleryTextCacheFile.exists()) return;
      final Uint8List bytes = await _galleryTextCacheFile.readAsBytes();
      // Decompress off the UI isolate; jsonDecode of the (capped) map is light.
      final Uint8List decompressed = await compute(_decompressJson, bytes);
      final dynamic content = jsonDecode(utf8.decode(decompressed));
      if (content is! Map) return;
      content.forEach((key, value) {
        if (key is String && value is String) {
          _galleryTextCache[key] = value;
        }
      });
      _evictGalleryTextCache();
    } catch (_) {
      // Corrupt cache: ignore and rebuild from scratch.
    }
  }

  void _scheduleGalleryTextCacheSave() {
    _galleryTextSaveTimer?.cancel();
    _galleryTextSaveTimer = Timer(const Duration(seconds: 1), () async {
      try {
        await _galleryTextCacheFile.parent.create(recursive: true);
        // Serialize + gzip off the UI isolate so scroll-heavy bursts don't jank.
        final Uint8List compressed =
            await compute(_compressJson, jsonEncode(_galleryTextCache));
        await _galleryTextCacheFile.writeAsBytes(compressed, flush: true);
      } catch (e) {
        log.warning('Failed to save gallery text translation cache: $e');
      }
    });
  }

  /// Maps the [ImageTranslationSetting.targetLanguage] display string to a
  /// BCP-47 language code understood by Apple's Translation framework.
  String _appleTargetLanguage() {
    switch (imageTranslationSetting.targetLanguage.value) {
      case '简体中文':
        return 'zh-Hans';
      case '繁體中文':
        return 'zh-Hant';
      case 'English':
        return 'en';
      case '日本語':
        return 'ja';
      case '한국어':
        return 'ko';
      case 'Português':
        return 'pt';
      case 'Русский':
        return 'ru';
      default:
        return 'zh-Hans';
    }
  }

  /// Optional BCP-47 source language for Apple on-device translation, taken
  /// from the Apple Live Text recognition language. Null lets the native side
  /// auto-detect the source language.
  String? _appleSourceLanguage() {
    final String value = imageTranslationSetting.appleLiveTextLanguage.value;
    if (value.trim().isEmpty || value.trim() == 'auto') {
      return null;
    }
    return value.split(',').first.trim();
  }

  Future<String> _translate(String sourceText) async {
    final List<String> sourceLines = const LineSplitter().convert(sourceText);
    final String numberedSource = sourceLines
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}: ${entry.value}')
        .join('\n');
    final Dio dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90)));
    final CancelToken cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    final ImageTranslationProvider provider =
        imageTranslationSetting.translatorProvider.value;
    final String endpoint = _translationEndpoint(
        imageTranslationSetting.translatorEndpoint.value!, provider);
    final String instruction =
        'You translate comic dialogue accurately. Preserve line order, names, punctuation, and sound effects. '
        'Return exactly one translated line per input line, numbered the same as the input (e.g. "1: ..."). '
        'Do not add headings, labels, numbering, or reasoning/think blocks.';
    final String prompt =
        'Translate the following comic text into ${imageTranslationSetting.targetLanguage.value}. '
        'Keep the same line numbers:\n\n$numberedSource';
    try {
      if (provider == ImageTranslationProvider.anthropic) {
        final Response<dynamic> response = await dio.post(endpoint,
            options: Options(
                headers: _anthropicHeaders(
                    imageTranslationSetting.translatorApiKey.value!)),
            cancelToken: cancelToken,
            data: {
              'model': imageTranslationSetting.translatorModel.value,
              'max_tokens': 2048,
              'system': instruction,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              ...?_thinkingParam(),
            });
        final dynamic blocks =
            response.data is Map ? response.data['content'] : null;
        if (blocks is List) {
          final String content = blocks
              .whereType<Map>()
              .map((block) => block['text'])
              .whereType<String>()
              .join('\n')
              .trim();
          if (content.isNotEmpty) {
            return _parseNumberedTranslations(
                    _stripReasoning(content), sourceLines.length)
                .join('\n');
          }
        }
      } else {
        final Response<dynamic> response = await dio.post(endpoint,
            options: Options(
                headers: _openAIHeaders(
                    imageTranslationSetting.translatorApiKey.value!)),
            cancelToken: cancelToken,
            data: {
              'model': imageTranslationSetting.translatorModel.value,
              'temperature': 0.2,
              'messages': [
                {'role': 'system', 'content': instruction},
                {'role': 'user', 'content': prompt},
              ],
              ...?_thinkingParam(),
            });
        final dynamic choices =
            response.data is Map ? response.data['choices'] : null;
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final dynamic message = choices.first['message'];
          final dynamic content = message is Map ? message['content'] : null;
          if (content is String && content.trim().isNotEmpty) {
            return _parseNumberedTranslations(
                    _stripReasoning(content.trim()), sourceLines.length)
                .join('\n');
          }
        }
      }
      throw const ImageTranslationException('TRANSLATION_INVALID_RESPONSE');
    } finally {
      _activeCancelToken = null;
    }
  }

  /// Parses numbered model output back into source-line order. Lines that
  /// cannot be parsed fall back to sequential order, which prevents a model
  /// reordering or skipping a line from shifting every later bubble.
  List<String> _parseNumberedTranslations(String text, int lineCount) {
    final List<String?> result = List.filled(lineCount, null);
    int fallbackIndex = 0;
    for (final String rawLine in const LineSplitter().convert(text)) {
      final String line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final RegExpMatch? match =
          RegExp(r'^\s*(\d+)\s*[:：.]?\s*(.*)$').firstMatch(line);
      if (match != null) {
        final int? index = int.tryParse(match.group(1)!);
        if (index != null && index >= 1 && index <= lineCount) {
          result[index - 1] = match.group(2)!.trim();
          continue;
        }
      }
      while (fallbackIndex < lineCount && result[fallbackIndex] != null) {
        fallbackIndex++;
      }
      if (fallbackIndex < lineCount) {
        result[fallbackIndex] = line;
        fallbackIndex++;
      }
    }
    return result.map((line) => line ?? '').toList();
  }

  /// Removes model reasoning artifacts such as <think>...</think> so only the
  /// actual translation is embedded onto the image.
  String _stripReasoning(String text) {
    String result = text.replaceAllMapped(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
      (_) => '',
    );
    result = result.replaceAllMapped(
      RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
      (_) => '',
    );
    result = result.replaceAllMapped(
      RegExp(r'\[/?reasoning\]', caseSensitive: false),
      (_) => '',
    );
    return result.replaceAll(RegExp(r'\n\s*\n+'), '\n').trim();
  }

  /// MiniMax-M3 accepts thinking.type adaptive/disabled; other models keep
  /// their default behavior.
  Map<String, dynamic>? _thinkingParam() {
    final String model =
        imageTranslationSetting.translatorModel.value.toLowerCase();
    if (!model.contains('minimax') && !model.contains('m3')) {
      return null;
    }
    return {
      'thinking': {
        'type': imageTranslationSetting.enableThinking.value
            ? 'adaptive'
            : 'disabled',
      },
    };
  }

  Future<List<String>> fetchModels({
    required ImageTranslationProvider provider,
    required String apiBaseUrl,
    required String apiKey,
  }) async {
    final String baseUrl = _trimUrl(apiBaseUrl);
    if (baseUrl.isEmpty || apiKey.trim().isEmpty) {
      throw const ImageTranslationException('API_CONFIGURATION_REQUIRED');
    }
    final Dio dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30)));
    final Response<dynamic> response = await dio.get(
      _modelsEndpoint(baseUrl, provider),
      options: Options(
          headers: provider == ImageTranslationProvider.anthropic
              ? _anthropicHeaders(apiKey)
              : _openAIHeaders(apiKey)),
    );
    final dynamic models = response.data is Map ? response.data['data'] : null;
    if (models is! List) {
      throw const ImageTranslationException('MODELS_INVALID_RESPONSE');
    }
    final List<String> ids = models
        .whereType<Map>()
        .map((model) => model['id'])
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (ids.isEmpty) throw const ImageTranslationException('MODELS_EMPTY');
    return ids;
  }

  Future<String?> discoverTessdataDirectory(String executable) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)
      return null;
    final ProcessResult result =
        await Process.run(executable, ['--list-langs']);
    if (result.exitCode != 0) return null;
    final Match? match =
        RegExp(r'"([^"]+)"').firstMatch(result.stdout.toString());
    final String? path = match?.group(1);
    return path != null && await Directory(path).exists() ? path : null;
  }

  Future<List<String>> installedOcrLanguages(
      {required String executable}) async {
    final ProcessResult result =
        await Process.run(executable, ['--list-langs']);
    if (result.exitCode != 0)
      throw const ImageTranslationException('OCR_UNAVAILABLE');
    return const LineSplitter()
        .convert(result.stdout.toString())
        .skipWhile((line) => line.contains('available languages'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> checkPaddleOcr({required String executable}) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }
    final ProcessResult result = await Process.run(executable, ['--help']);
    if (result.exitCode != 0) {
      throw const ImageTranslationException('OCR_UNAVAILABLE');
    }
  }

  Future<void> preparePaddleRuntime({
    required bool downloadVl16,
    void Function(String stage)? onStage,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }
    preparingPaddle = true;
    paddleStage = null;
    _paddleOutput.clear();
    update([paddlePrepareId]);
    try {
      await _paddleRoot.create(recursive: true);
      if (!await File(_paddlePython).exists()) {
        _setPaddleStage('Creating Python environment', onStage);
        final String? bootstrap = await _findCompatiblePython();
        if (bootstrap == null) {
          throw const ImageTranslationException('PADDLE_PYTHON_UNSUPPORTED');
        }
        final ProcessResult create =
            await Process.run(bootstrap, ['-m', 'venv', _paddleVenv.path]);
        if (create.exitCode != 0) {
          throw const ImageTranslationException('PADDLE_VENV_CREATE_FAILED');
        }
      }
      _setPaddleStage('Installing PaddleOCR runtime', onStage);
      final Process installProcess = await Process.start(_paddlePython, [
        '-m',
        'pip',
        'install',
        '--upgrade',
        'paddleocr==3.7.0',
        'paddlepaddle',
        'huggingface_hub',
      ]);
      await _streamProcessOutput(installProcess);
      if (await installProcess.exitCode != 0) {
        throw const ImageTranslationException('PADDLE_RUNTIME_INSTALL_FAILED');
      }
      if (downloadVl16) {
        _setPaddleStage(
            'Downloading PaddleOCR-VL-1.6 from Hugging Face', onStage);
        final String downloadScript =
            """from huggingface_hub import snapshot_download
snapshot_download(repo_id='$paddleOcrVlRepo', cache_dir=r'''${_paddleHuggingFaceCache.path}''')
""";
        final Process downloadProcess = await Process.start(_paddlePython, [
          '-c',
          downloadScript
        ], environment: {
          'HF_HOME': _paddleHuggingFaceCache.path,
          'PADDLEX_HOME': _paddleRoot.path,
          'PADDLE_PDX_MODEL_SOURCE': 'huggingface',
          'HF_HUB_DISABLE_XET': '1',
        });
        await _streamProcessOutput(downloadProcess);
        if (await downloadProcess.exitCode != 0) {
          throw const ImageTranslationException('PADDLE_VL_DOWNLOAD_FAILED');
        }
      } else {
        _setPaddleStage('Downloading PP-OCRv6 models', onStage);
        final String language = imageTranslationSetting.paddleOcrLanguage.value;
        final String preloadScript = """
import numpy as np
from paddleocr import PaddleOCR
language = '$language'
pipeline = PaddleOCR(
    lang=language,
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=language in ('japan', 'chinese_cht', 'korean'),
)
try:
    pipeline.predict(np.zeros((64, 64, 3), dtype=np.uint8))
except Exception:
    pass
""";
        final Process preloadProcess = await Process.start(_paddlePython, [
          '-c',
          preloadScript
        ], environment: {
          'HF_HOME': _paddleHuggingFaceCache.path,
          'PADDLEX_HOME': _paddleRoot.path,
          'PADDLE_PDX_MODEL_SOURCE': 'huggingface',
          'HF_HUB_DISABLE_XET': '1',
        });
        await _streamProcessOutput(preloadProcess);
        if (await preloadProcess.exitCode != 0) {
          throw const ImageTranslationException('PADDLE_MODEL_DOWNLOAD_FAILED');
        }
      }
    } finally {
      preparingPaddle = false;
      paddleStage = null;
      update([paddlePrepareId]);
    }
  }

  void _setPaddleStage(String stage, void Function(String stage)? onStage) {
    paddleStage = stage;
    update([paddlePrepareId]);
    onStage?.call(stage);
  }

  void _appendPaddleOutput(String line) {
    if (_paddleOutput.length >= 300) {
      _paddleOutput.removeAt(0);
    }
    _paddleOutput.add(line);
    update([paddlePrepareId]);
  }

  Future<void> _streamProcessOutput(Process process) async {
    await Future.wait([
      _readProcessStream(process.stdout),
      _readProcessStream(process.stderr),
    ]);
  }

  Future<void> _readProcessStream(Stream<List<int>> stream) async {
    final StringBuffer buffer = StringBuffer();
    await for (final List<int> chunk in stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      final String text = buffer.toString();
      final List<String> lines = text.split(RegExp(r'[\r\n]+'));
      buffer.clear();
      buffer.write(lines.removeLast());
      for (final String line in lines) {
        final String trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _appendPaddleOutput(trimmed);
        }
      }
    }
    final String rest = buffer.toString().trim();
    if (rest.isNotEmpty) {
      _appendPaddleOutput(rest);
    }
  }

  String paddleRuntimePath() => _paddleRoot.path;

  Future<String?> _findCompatiblePython() async {
    final List<String> candidates = Platform.isWindows
        ? ['py', 'python']
        : ['python3.12', 'python3.11', 'python3.10', 'python3'];
    for (final String candidate in candidates) {
      try {
        final ProcessResult result =
            await Process.run(candidate, ['--version']);
        final Match? version = RegExp(r'Python 3\.(\d+)')
            .firstMatch('${result.stdout}${result.stderr}');
        final int? minor = int.tryParse(version?.group(1) ?? '');
        if (result.exitCode == 0 &&
            minor != null &&
            minor >= 9 &&
            minor <= 12) {
          return candidate;
        }
      } on ProcessException {
        continue;
      }
    }
    return null;
  }

  Future<void> downloadOcrModel({
    required String languageCode,
    required OcrModelSource source,
    required String dataDirectory,
    void Function(int received, int total)? onProgress,
  }) async {
    _downloadingOcrModels.add(languageCode);
    _ocrModelDownloadProgress[languageCode] = null;
    update([ocrModelDownloadId(languageCode)]);
    final Directory directory = Directory(dataDirectory);
    if (!await directory.exists()) await directory.create(recursive: true);
    final String url = _ocrModelUrl(languageCode, source);
    final File target = File(join(directory.path, '$languageCode.traineddata'));
    final File partial = File('${target.path}.download');
    try {
      await Dio().download(
        url,
        partial.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _ocrModelDownloadProgress[languageCode] = received / total;
            update([ocrModelDownloadId(languageCode)]);
          }
          onProgress?.call(received, total);
        },
      );
      if (await partial.length() == 0) {
        await partial.delete();
        throw const ImageTranslationException('OCR_MODEL_DOWNLOAD_FAILED');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
    } finally {
      _downloadingOcrModels.remove(languageCode);
      _ocrModelDownloadProgress.remove(languageCode);
      update([ocrModelDownloadId(languageCode)]);
    }
  }

  String _modelsEndpoint(String baseUrl, ImageTranslationProvider provider) =>
      provider == ImageTranslationProvider.anthropic
          ? _appendPath(baseUrl, 'models')
          : _appendPath(baseUrl, 'models');

  String _translationEndpoint(
          String baseUrl, ImageTranslationProvider provider) =>
      _appendPath(
          baseUrl,
          provider == ImageTranslationProvider.anthropic
              ? 'messages'
              : 'chat/completions');

  String _appendPath(String baseUrl, String path) {
    final String normalized = _trimUrl(baseUrl);
    return '$normalized/$path';
  }

  String _trimUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  Map<String, String> _openAIHeaders(String apiKey) => {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      };

  Map<String, String> _anthropicHeaders(String apiKey) => {
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };

  String _ocrModelUrl(String languageCode, OcrModelSource source) {
    final String fileName = '$languageCode.traineddata';
    switch (source) {
      case OcrModelSource.giteeMirror:
        return 'https://gitee.com/colluslau/tessdata_fast/raw/master/$fileName';
      case OcrModelSource.githubOfficial:
        return 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/$fileName';
    }
  }

  /// Upper bound on in-memory translation results. Batch-translating a long
  /// gallery used to accumulate one entry per page forever; evicting the
  /// least-recently-used entry keeps memory bounded. The on-disk persistent
  /// cache is untouched, so an evicted page is re-read from disk on demand.
  static const int maxCachedResults = 200;

  void _set(String cacheKey, ImageTranslationResult result) {
    // Remove-then-reinsert so a re-used key counts as most-recently-used
    // (Dart maps keep insertion order).
    _results.remove(cacheKey);
    _results[cacheKey] = result;
    if (_results.length > maxCachedResults) {
      final String evicted = _results.keys.first;
      _results.remove(evicted);
      log.warning(
          'Image translation result cache exceeded $maxCachedResults entries, '
          'evicted oldest: $evicted');
      update([taskId(evicted)]);
    }
    update([taskId(cacheKey)]);
  }
}

class ImageTranslationException implements Exception {
  final String code;

  const ImageTranslationException(this.code);
}

class _TesseractLine {
  final List<String> _words = [];
  final List<double> _confidences = [];
  double _left = double.infinity;
  double _top = double.infinity;
  double _right = 0;
  double _bottom = 0;

  void add(String word, double confidence, double left, double top,
      double width, double height) {
    _words.add(word);
    _confidences.add(confidence);
    _left = _left < left ? _left : left;
    _top = _top < top ? _top : top;
    _right = _right > left + width ? _right : left + width;
    _bottom = _bottom > top + height ? _bottom : top + height;
  }

  RecognizedTextBlock toBlock() {
    final double confidence = _confidences.isEmpty
        ? 0
        : _confidences.reduce((a, b) => a + b) / _confidences.length;
    return RecognizedTextBlock(
        text: _words.join(' '),
        confidence: confidence,
        left: _left.isFinite ? _left : 0,
        top: _top.isFinite ? _top : 0,
        width: _right - (_left.isFinite ? _left : 0),
        height: _bottom - (_top.isFinite ? _top : 0));
  }
}
