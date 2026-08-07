import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';

import '../model/image_translation.dart';
import '../setting/image_translation_setting.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

ImageTranslationService imageTranslationService = ImageTranslationService();

class ImageTranslationService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String taskIdPrefix = 'imageTranslation';

  final Map<String, ImageTranslationResult> _results = {};
  static const String paddleOcrVlRepo = 'PaddlePaddle/PaddleOCR-VL-1.6';

  Directory get _paddleRoot => Directory(join(
      (pathService.appSupportDir ?? pathService.getVisibleDir()).path,
      'image_translation',
      'paddleocr'));

  Directory get _paddleVenv => Directory(join(_paddleRoot.path, 'venv'));

  Directory get _paddleHuggingFaceCache =>
      Directory(join(_paddleRoot.path, 'huggingface'));

  String get _paddlePython => Platform.isWindows
      ? join(_paddleVenv.path, 'Scripts', 'python.exe')
      : join(_paddleVenv.path, 'bin', 'python');

  String taskId(String cacheKey) => '$taskIdPrefix::$cacheKey';

  Directory get _translationCacheDirectory => Directory(join(
      (pathService.appSupportDir ?? pathService.getVisibleDir()).path,
      'image_translation',
      'cache'));

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

    String? temporaryPath;
    try {
      final String imagePath;
      if (request.imagePath != null) {
        imagePath = request.imagePath!;
      } else {
        final List<int> bytes = request.imageBytes!;
        final String fileName =
            'image_translation_${sha256.convert(bytes).toString()}.png';
        final File temporaryFile =
            File(join(pathService.tempDir.path, fileName));
        await temporaryFile.writeAsBytes(bytes, flush: true);
        temporaryPath = temporaryFile.path;
        imagePath = temporaryFile.path;
      }

      final String persistentKey =
          await _persistentCacheKey(request, imagePath);
      final ImageTranslationResult? cached =
          await _readPersistentResult(persistentKey);
      if (!force && cached != null) {
        _set(request.cacheKey, cached);
        return;
      }

      final Uint8List sourceBytes = request.imageBytes == null
          ? await File(imagePath).readAsBytes()
          : Uint8List.fromList(request.imageBytes!);
      final ui.Codec codec = await ui.instantiateImageCodec(sourceBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final int imageWidth = frame.image.width;
      final int imageHeight = frame.image.height;
      frame.image.dispose();
      codec.dispose();

      final List<RecognizedTextBlock> blocks = await _recognize(imagePath);
      final String sourceText = blocks
          .map((block) => block.text)
          .where((text) => text.isNotEmpty)
          .join('\n');
      if (sourceText.isEmpty) {
        throw const ImageTranslationException('NO_TEXT');
      }

      if (!imageTranslationSetting.isTranslatorConfigured) {
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
      final String translatedText = await _translate(sourceText);
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
    } on ImageTranslationException catch (e, stack) {
      log.warning('Image translation failed: ${e.code}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed, errorMessage: e.code));
      log.trace(stack);
    } on ProcessException catch (e, stack) {
      log.warning('Image OCR executable is unavailable: ${e.executable}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed,
              errorMessage: 'OCR_UNAVAILABLE'));
      log.trace(stack);
    } on DioException catch (e, stack) {
      log.warning('Image translation request failed: ${e.message}');
      _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
              status: ImageTranslationStatus.failed,
              errorMessage: 'TRANSLATION_REQUEST_FAILED'));
      log.trace(stack);
    } catch (e, stack) {
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

  Future<String> _persistentCacheKey(
      ImageTranslationRequest request, String imagePath) async {
    final List<int> imageBytes =
        request.imageBytes ?? await File(imagePath).readAsBytes();
    final String imageHash = sha256.convert(imageBytes).toString();
    final String configFingerprint = jsonEncode({
      'ocrEngine': imageTranslationSetting.ocrEngine.value.name,
      'ocrLanguage': imageTranslationSetting.ocrLanguage.value,
      'paddleLanguage': imageTranslationSetting.paddleOcrLanguage.value,
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
      final dynamic content = jsonDecode(await cacheFile.readAsString());
      if (content is! Map) return null;
      final ImageTranslationResult result =
          ImageTranslationResult.successFromJson(
              Map<String, dynamic>.from(content));
      return result.translatedText.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentResult(
      String key, ImageTranslationResult result) async {
    await _translationCacheDirectory.create(recursive: true);
    final File cacheFile =
        File(join(_translationCacheDirectory.path, '$key.json'));
    await cacheFile.writeAsString(jsonEncode(result.toJson()), flush: true);
  }

  Future<List<RecognizedTextBlock>> _recognize(String imagePath) async {
    if (imageTranslationSetting.ocrEngine.value == ImageOcrEngine.paddleOcr ||
        imageTranslationSetting.ocrEngine.value ==
            ImageOcrEngine.paddleOcrVl16) {
      return _recognizeWithPaddleOcr(imagePath);
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
    final ProcessResult process = await Process.run(
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
    if (process.exitCode != 0) {
      log.warning(
          'Tesseract exited with ${process.exitCode}: ${process.stderr}');
      throw const ImageTranslationException('OCR_FAILED');
    }

    final Map<String, _TesseractLine> lines = {};
    for (final String rawLine
        in const LineSplitter().convert(process.stdout.toString())) {
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
    return lines.values
        .map((line) => line.toBlock())
        .where((block) => block.text.isNotEmpty)
        .toList();
  }

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
    final ProcessResult process = await Process.run(_paddlePython, [
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
    if (process.exitCode != 0) {
      log.warning(
          'PaddleOCR exited with ${process.exitCode}: ${process.stderr}');
      throw const ImageTranslationException('OCR_FAILED');
    }
    final List<RecognizedTextBlock> blocks =
        _paddleBlocks(process.stdout.toString());
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
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    image.dispose();
    if (data == null)
      throw const ImageTranslationException('OVERLAY_ENCODE_FAILED');
    final Directory directory = Directory(join(
        pathService.getVisibleDir().path, 'image_translation', 'overlays'));
    await directory.create(recursive: true);
    final File output = File(join(directory.path,
        'translation_${sha256.convert(source).toString().substring(0, 16)}.png'));
    await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return output;
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

  Future<String> _translate(String sourceText) async {
    final Dio dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90)));
    final ImageTranslationProvider provider =
        imageTranslationSetting.translatorProvider.value;
    final String endpoint = _translationEndpoint(
        imageTranslationSetting.translatorEndpoint.value!, provider);
    final String instruction =
        'You translate comic dialogue accurately. Preserve line order, names, punctuation, and sound effects. Return exactly one output line for every input line, in the same order. Do not add headings, labels, or numbering.';
    final String prompt =
        'Translate the following comic text into ${imageTranslationSetting.targetLanguage.value}:\n\n$sourceText';
    if (provider == ImageTranslationProvider.anthropic) {
      final Response<dynamic> response = await dio.post(endpoint,
          options: Options(
              headers: _anthropicHeaders(
                  imageTranslationSetting.translatorApiKey.value!)),
          data: {
            'model': imageTranslationSetting.translatorModel.value,
            'max_tokens': 2048,
            'system': instruction,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
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
        if (content.isNotEmpty) return content;
      }
    } else {
      final Response<dynamic> response = await dio.post(endpoint,
          options: Options(
              headers: _openAIHeaders(
                  imageTranslationSetting.translatorApiKey.value!)),
          data: {
            'model': imageTranslationSetting.translatorModel.value,
            'temperature': 0.2,
            'messages': [
              {'role': 'system', 'content': instruction},
              {'role': 'user', 'content': prompt},
            ],
          });
      final dynamic choices =
          response.data is Map ? response.data['choices'] : null;
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final dynamic message = choices.first['message'];
        final dynamic content = message is Map ? message['content'] : null;
        if (content is String && content.trim().isNotEmpty)
          return content.trim();
      }
    }
    throw const ImageTranslationException('TRANSLATION_INVALID_RESPONSE');
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
    await _paddleRoot.create(recursive: true);
    if (!await File(_paddlePython).exists()) {
      onStage?.call('Creating Python environment');
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
    onStage?.call('Installing PaddleOCR runtime');
    final ProcessResult install = await Process.run(_paddlePython, [
      '-m',
      'pip',
      'install',
      '--upgrade',
      'paddleocr==3.7.0',
      'paddlepaddle',
      'huggingface_hub',
    ]);
    if (install.exitCode != 0) {
      throw const ImageTranslationException('PADDLE_RUNTIME_INSTALL_FAILED');
    }
    if (downloadVl16) {
      onStage?.call('Downloading PaddleOCR-VL-1.6 from Hugging Face');
      final String downloadScript =
          """from huggingface_hub import snapshot_download
snapshot_download(repo_id='$paddleOcrVlRepo', cache_dir=r'''${_paddleHuggingFaceCache.path}''')
""";
      final ProcessResult download = await Process.run(_paddlePython, [
        '-c',
        downloadScript
      ], environment: {
        'HF_HOME': _paddleHuggingFaceCache.path,
        'PADDLEX_HOME': _paddleRoot.path,
        'PADDLE_PDX_MODEL_SOURCE': 'huggingface',
        'HF_HUB_DISABLE_XET': '1',
      });
      if (download.exitCode != 0) {
        throw const ImageTranslationException('PADDLE_VL_DOWNLOAD_FAILED');
      }
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
    final Directory directory = Directory(dataDirectory);
    if (!await directory.exists()) await directory.create(recursive: true);
    final String url = _ocrModelUrl(languageCode, source);
    final File target = File(join(directory.path, '$languageCode.traineddata'));
    final File partial = File('${target.path}.download');
    await Dio().download(url, partial.path, onReceiveProgress: onProgress);
    if (await partial.length() == 0) {
      await partial.delete();
      throw const ImageTranslationException('OCR_MODEL_DOWNLOAD_FAILED');
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
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

  void _set(String cacheKey, ImageTranslationResult result) {
    _results[cacheKey] = result;
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
