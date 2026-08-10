import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
import '../setting/inference_setting.dart';
import 'inference/inference_exception.dart';
import 'inference/inference_task.dart';
import 'inference/ocr_inference_engine.dart';
import 'inference/onnx_model_store.dart';
import 'inference_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';
import '../utils/image_text_grouping.dart';

ImageTranslationService imageTranslationService = ImageTranslationService();

/// Result of the recognition step. `imageWidth`/`imageHeight` are the upright
/// (orientation-applied) pixel dimensions for engines that provide them (Apple
/// Live Text), so the overlay scales blocks in the same space the image is
/// actually displayed in. Tesseract/Paddle return null and the caller falls
/// back to its header-based dimension probe.
typedef _RecognizeResult =
    ({List<RecognizedTextBlock> blocks, int? imageWidth, int? imageHeight});

/// The recognized source of one page, produced by [ImageTranslationService.recognizeImage]
/// and consumed by [ImageTranslationService.translateRecognizedText]. Carrying it
/// between the two stages lets the batch pipeline overlap the next page's OCR
/// with the current page's translation.
class RecognizedImage {
  const RecognizedImage({
    required this.cacheKey,
    required this.persistentKey,
    required this.sourceText,
    required this.blocks,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String cacheKey;
  final String persistentKey;
  final String sourceText;
  final List<RecognizedTextBlock> blocks;
  final int imageWidth;
  final int imageHeight;
}

class ImageTranslationService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String taskIdPrefix = 'imageTranslation';
  static const String batchProgressId = 'imageTranslationBatchProgress';
  static const String liveTextOcrChannelName =
      'top.jtmonster.jhentai.live_text_ocr';

  final Map<String, ImageTranslationResult> _results = {};

  /// Batch translation progress shown by the read-page top banner.
  bool isBatchTranslating = false;
  int batchTotal = 0;
  int batchCompleted = 0;
  ImageTranslationStage currentStage = ImageTranslationStage.idle;
  bool _cancelRequested = false;

  /// Monotonic batch generation. Bumped every time a batch starts; a stale
  /// batch still unwinding after a cancel can only write shared progress state
  /// when its captured generation is still current, so it can never clobber a
  /// newer batch's banner/progress.
  int _batchGeneration = 0;
  Process? _activeProcess;
  CancelToken? _activeCancelToken;
  InferenceCancellationToken? _activeInferenceToken;

  /// Apple Live Text OCR (Vision framework) is exposed over a platform channel
  /// registered natively in ios/Runner and macos/Runner.
  late final MethodChannel _liveTextChannel = MethodChannel(
    liveTextOcrChannelName,
  );

  int beginBatch(int total) {
    _batchGeneration++;
    _cancelRequested = false;
    isBatchTranslating = true;
    batchTotal = total;
    batchCompleted = 0;
    currentStage = ImageTranslationStage.idle;
    update([batchProgressId]);
    return _batchGeneration;
  }

  void endBatch(int generation) {
    // A cancelled batch still unwinding after a newer batch started must not
    // reset the newer batch's shared progress state.
    if (generation != _batchGeneration) {
      return;
    }
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
    _activeInferenceToken?.cancel('image translation cancelled');
    _activeInferenceToken = null;
    update([batchProgressId]);
  }

  bool get isCancelRequested => _cancelRequested;

  /// Whether [generation] is the currently running batch. Batch loops guard
  /// their shared progress writes with this so an unwinding stale batch cannot
  /// clobber a newer one.
  bool isCurrentBatch(int generation) => generation == _batchGeneration;

  /// Clears the one-shot cancel latch before a single-page (non-batch)
  /// translation. cancelBatch() arms _cancelRequested and only the batch
  /// lifecycle (beginBatch/endBatch) clears it; single-page translations have
  /// no batch lifecycle of their own, so without this a single cancel (the
  /// status-chip X, or leaving the read page) would permanently disable every
  /// later context-menu translate.
  void resetCancelFlag() {
    _cancelRequested = false;
  }

  /// Removes an in-memory result. Used when the source image is reloaded so a
  /// stale overlay is not drawn over the new image.
  void removeResult(String cacheKey) => _removeResult(cacheKey);

  void _setStage(ImageTranslationStage stage) {
    currentStage = stage;
    update([batchProgressId]);
  }

  String taskId(String cacheKey) => '$taskIdPrefix::$cacheKey';

  Directory get _translationCacheDirectory =>
      Directory(join(pathService.jhOcrModelDir.path, 'cache'));

  ImageTranslationResult resultFor(String cacheKey) =>
      _results[cacheKey] ?? const ImageTranslationResult.idle();

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies
        ..add(imageTranslationSetting)
        ..add(inferenceService);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  /// OCR stage of a translation: reads the image, runs recognition and returns
  /// the recognized source for the translation stage. Returns null when the
  /// page should be skipped (already translated / image unavailable / no text).
  /// Split from [translate] so the batch pipeline can overlap the next page's
  /// OCR with the current page's translation.
  Future<RecognizedImage?> recognizeImage(
    ImageTranslationRequest request, {
    bool force = false,
  }) async {
    final ImageTranslationResult existing = resultFor(request.cacheKey);
    if (!force &&
        (existing.status == ImageTranslationStatus.recognizing ||
            existing.status == ImageTranslationStatus.translating ||
            existing.status == ImageTranslationStatus.success)) {
      return null;
    }

    _set(
      request.cacheKey,
      const ImageTranslationResult(status: ImageTranslationStatus.recognizing),
    );
    _setStage(ImageTranslationStage.recognizing);

    String? temporaryPath;
    try {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return null;
      }
      // Read the image bytes exactly once: they feed the persistent-cache
      // hash and (for bytes-based requests) the OCR subprocess file.
      // Previously the file was read again inside _persistentCacheKey and a
      // just-written temporary file was read back.
      final List<int> sourceBytes =
          request.imageBytes == null
              ? await File(request.imagePath!).readAsBytes()
              : request.imageBytes!;

      // Hashing the full image on the UI isolate drops frames on every page
      // (SHA-256 over a few MB is tens of ms); run it off-isolate. The single
      // hash also names the bytes-path temp file below, avoiding a second
      // full-image hash.
      final String imageHash = await compute(_sha256Hex, sourceBytes);
      final String persistentKey = _persistentCacheKey(request, imageHash);
      final ImageTranslationResult? cached = await _readPersistentResult(
        persistentKey,
      );
      if (!force && cached != null) {
        _set(request.cacheKey, cached.copyWith(fromCache: true));
        return null;
      }

      // The OCR subprocess needs a real file path; only bytes-based requests
      // materialize one, and only once a translation is actually about to run.
      final String imagePath;
      if (request.imagePath != null) {
        imagePath = request.imagePath!;
      } else {
        final String fileName = 'image_translation_$imageHash.png';
        final File temporaryFile = File(
          join(pathService.tempDir.path, fileName),
        );
        await temporaryFile.writeAsBytes(sourceBytes, flush: true);
        temporaryPath = temporaryFile.path;
        imagePath = temporaryFile.path;
      }

      final _RecognizeResult recognized = await _recognize(imagePath);
      final List<RecognizedTextBlock> blocks = recognized.blocks;
      // Both on-device engines (ONNX, Apple Live Text) always report the
      // upright pixel dimensions; probe the image header only as a fallback so
      // the hot path never copies the page bytes on the UI isolate.
      final int imageWidth;
      final int imageHeight;
      if (recognized.imageWidth != null && recognized.imageHeight != null) {
        imageWidth = recognized.imageWidth!;
        imageHeight = recognized.imageHeight!;
      } else {
        final (int width, int height) = await _probeImageDimensions(
          sourceBytes,
        );
        imageWidth = width;
        imageHeight = height;
      }
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return null;
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
        return null;
      }

      _set(
        request.cacheKey,
        ImageTranslationResult(
          status: ImageTranslationStatus.translating,
          sourceText: sourceText,
          blocks: blocks,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
      );
      await _writePersistentResult(persistentKey, resultFor(request.cacheKey));
      _setStage(ImageTranslationStage.translating);
      return RecognizedImage(
        cacheKey: request.cacheKey,
        persistentKey: persistentKey,
        sourceText: sourceText,
        blocks: blocks,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    } on ImageTranslationException catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return null;
      }
      log.warning('Image translation failed: ${e.code}');
      _set(
        request.cacheKey,
        resultFor(
          request.cacheKey,
        ).copyWith(status: ImageTranslationStatus.failed, errorMessage: e.code),
      );
      log.trace(stack);
    } on ProcessException catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return null;
      }
      log.warning('Image OCR executable is unavailable: ${e.executable}');
      _set(
        request.cacheKey,
        resultFor(request.cacheKey).copyWith(
          status: ImageTranslationStatus.failed,
          errorMessage: 'OCR_UNAVAILABLE',
        ),
      );
      log.trace(stack);
    } catch (e, stack) {
      if (_cancelRequested) {
        _removeResult(request.cacheKey);
        return null;
      }
      log.error('Image translation failed', e, stack);
      _set(
        request.cacheKey,
        resultFor(request.cacheKey).copyWith(
          status: ImageTranslationStatus.failed,
          errorMessage: 'TRANSLATION_FAILED',
        ),
      );
    } finally {
      if (temporaryPath != null) {
        File(temporaryPath).delete().ignore();
      }
    }
    return null;
  }

  /// Translation stage: translates the recognized source text and finalizes
  /// the result. Called after [recognizeImage] so the batch pipeline can run
  /// the next page's OCR while this translation is in flight.
  Future<void> translateRecognizedText(
    ImageTranslationRequest request,
    RecognizedImage recognized,
  ) async {
    try {
      final String translatedText =
          imageTranslationSetting.usesAppleOnDeviceTranslation
              ? await _translateWithApple(recognized.blocks)
              : await _translate(recognized.blocks);
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
          sourceText: recognized.sourceText,
          translatedText: translatedText,
          blocks: recognized.blocks,
          imageWidth: recognized.imageWidth,
          imageHeight: recognized.imageHeight,
        ),
      );
      await _writePersistentResult(
        recognized.persistentKey,
        resultFor(request.cacheKey),
      );
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
          status: ImageTranslationStatus.failed,
          errorMessage: e.code,
        ),
      );
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
          errorMessage: 'TRANSLATION_REQUEST_FAILED',
        ),
      );
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
          errorMessage: 'TRANSLATION_FAILED',
        ),
      );
    }
  }

  /// Translates a single image end-to-end (OCR then translation). Batch
  /// translation uses [recognizeImage] + [translateRecognizedText] directly so
  /// the pipeline can overlap the next page's OCR with the current translation.
  Future<void> translate(
    ImageTranslationRequest request, {
    bool force = false,
  }) async {
    // Single-page retry/translate: clear any stale cancel latch so a previous
    // cancelled translate (which never went through the batch lifecycle) does
    // not silently disable this one.
    _cancelRequested = false;
    final RecognizedImage? recognized = await recognizeImage(
      request,
      force: force,
    );
    if (recognized == null) {
      return;
    }
    await translateRecognizedText(request, recognized);
  }

  void _removeResult(String cacheKey) {
    _results.remove(cacheKey);
    update([taskId(cacheKey)]);
  }

  String _persistentCacheKey(
    ImageTranslationRequest request,
    String imageHash,
  ) {
    final String configFingerprint = jsonEncode({
      'ocrEngine': imageTranslationSetting.ocrEngine.value.name,
      'appleLanguage': imageTranslationSetting.appleLiveTextLanguage.value,
      'appleUseApi':
          imageTranslationSetting.appleLiveTextUseThirdPartyApi.value,
      if (imageTranslationSetting.ocrEngine.value == ImageOcrEngine.onnx) ...{
        'onnxModel': OnnxModelStore.instance.fingerprintOf(
          imageTranslationSetting.onnxModelId.value,
        ),
        'onnxBackend':
            inferenceService.resolveBackendFor(InferenceDomain.ocr)?.name,
      },
      'provider': imageTranslationSetting.translatorProvider.value.name,
      'endpoint': imageTranslationSetting.translatorEndpoint.value,
      'model': imageTranslationSetting.translatorModel.value,
      'target': imageTranslationSetting.targetLanguage.value,
      // Group-aware translation (speech bubbles translated as one utterance).
      'promptVersion': 3,
    });
    return sha256
        .convert(utf8.encode('$imageHash:$configFingerprint'))
        .toString();
  }

  /// Probes the encoded image dimensions from its header. Only used as a
  /// fallback when an OCR engine reports no dimensions (both on-device engines
  /// always do), so the per-page hot path stays free of full-buffer copies.
  Future<(int, int)> _probeImageDimensions(List<int> sourceBytes) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(sourceBytes),
    );
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
      buffer,
    );
    final (int, int) dims = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return dims;
  }

  Future<ImageTranslationResult?> _readPersistentResult(String key) async {
    final File cacheFile = File(
      join(_translationCacheDirectory.path, '$key.json'),
    );
    if (!await cacheFile.exists()) return null;
    try {
      final dynamic content = jsonDecode(
        utf8.decode(
          await compute(_decompressJson, await cacheFile.readAsBytes()),
        ),
      );
      if (content is! Map) return null;
      final ImageTranslationResult result =
          ImageTranslationResult.successFromJson(
            Map<String, dynamic>.from(content),
          );
      final String cleaned = _stripReasoning(result.translatedText);
      return cleaned.isEmpty ? null : result.copyWith(translatedText: cleaned);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistentResult(
    String key,
    ImageTranslationResult result,
  ) async {
    await _translationCacheDirectory.create(recursive: true);
    final File cacheFile = File(
      join(_translationCacheDirectory.path, '$key.json'),
    );
    // gzip-compress off the UI isolate so batch translation never blocks it.
    await cacheFile.writeAsBytes(
      await compute(_compressJson, jsonEncode(result.toJson())),
      flush: true,
    );
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

  /// SHA-256 hex of the source image bytes. Runs off the UI isolate via
  /// [compute] so hashing a multi-MB page never blocks frame production.
  static String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  Future<_RecognizeResult> _recognize(String imagePath) async {
    if (imageTranslationSetting.ocrEngine.value ==
        ImageOcrEngine.appleLiveText) {
      return _recognizeWithAppleLiveText(imagePath);
    }
    // Custom mode is fixed to ONNX.
    return _recognizeWithOnnx(imagePath);
  }

  /// On-device PP-OCRv6 through the unified inference backend.
  Future<_RecognizeResult> _recognizeWithOnnx(String imagePath) async {
    final OcrInferenceEngine engine = inferenceService.ocrEngine;
    // No isReady pre-check here: recognize() itself throws
    // InferenceNotReadyException when the manifest/backend is unavailable and
    // the catch below maps it to OCR_NOT_CONFIGURED. Checking isReady first
    // would re-run the same synchronous manifest validation (sync disk I/O on
    // the UI isolate) a second time per page.
    final InferenceCancellationToken token = InferenceCancellationToken();
    _activeInferenceToken = token;
    try {
      final OcrInferenceResult result = await engine.recognize(
        imagePath,
        cancellationToken: token,
      );
      return (
        blocks: result.blocks,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
      );
    } on InferenceNotReadyException {
      throw const ImageTranslationException('OCR_NOT_CONFIGURED');
    } on InferenceCancelledException {
      throw const ImageTranslationException('OCR_CANCELLED');
    } finally {
      if (identical(_activeInferenceToken, token)) {
        _activeInferenceToken = null;
      }
    }
  }

  /// On-device OCR through Apple's Vision framework (Live Text). The native
  /// side runs VNRecognizeTextRequest off the main thread and returns text
  /// lines as top-left-origin pixel rectangles in the original upright image
  /// space, matching the [RecognizedTextBlock] convention. It also returns the
  /// upright pixel dimensions, which the caller must use for overlay scaling:
  /// the header-based dimension probe does not apply EXIF orientation, so on
  /// rotated pages it disagrees with the block coordinate space.
  Future<_RecognizeResult> _recognizeWithAppleLiveText(String imagePath) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw const ImageTranslationException('OCR_UNSUPPORTED_PLATFORM');
    }
    try {
      final Map<dynamic, dynamic>? response = await _liveTextChannel
          .invokeMethod<Map<dynamic, dynamic>>('recognizeText', {
            'path': imagePath,
            // Always an explicit list (a curated default for 'auto') so Vision
            // recognizes vertical CJK — its automatic language detection does
            // not reliably trigger vertical-text recognition.
            'languages': _appleLiveTextLanguages(),
            'automaticallyDetectsLanguage': false,
            'recognitionLevel': 'accurate',
            'maxDimension': 2200,
          });
      if (response == null) {
        throw const ImageTranslationException('OCR_FAILED');
      }
      final List<dynamic> rawLines =
          response['lines'] as List<dynamic>? ?? const [];
      final List<RecognizedTextBlock> blocks =
          rawLines
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

  /// Comma-separated BCP-47 codes from the Apple Live Text setting.
  ///
  /// For 'auto' a curated CJK + English default is used instead of Vision's
  /// automatic language detection, because auto-detection is unreliable for
  /// VERTICAL Japanese text — Apple requires the vertical-capable languages
  /// (Japanese / Chinese / Korean) to be set explicitly on the request.
  List<String>? _appleLiveTextLanguages() {
    final String value = imageTranslationSetting.appleLiveTextLanguage.value;
    if (value.trim().isEmpty || value.trim() == 'auto') {
      return const <String>['ja-JP', 'zh-Hans', 'zh-Hant', 'ko-KR', 'en-US'];
    }
    final List<String> languages =
        value
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

  Future<File> exportOverlay(ImageTranslationRequest request) async {
    final ImageTranslationResult result = resultFor(request.cacheKey);
    final List<String> translations =
        const LineSplitter()
            .convert(result.translatedText)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    final List<RecognizedTextBlock> blocks =
        result.blocks
            .where((block) => block.width > 4 && block.height > 4)
            .toList();
    if (result.status != ImageTranslationStatus.success ||
        translations.length != blocks.length) {
      throw const ImageTranslationException('OVERLAY_NOT_READY');
    }
    final Uint8List source = Uint8List.fromList(
      request.imageBytes ?? await File(request.imagePath!).readAsBytes(),
    );
    final ui.Codec codec = await ui.instantiateImageCodec(source);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..drawImage(frame.image, Offset.zero, Paint());
    // Adjacent lines of the same bubble (a group) share ONE background pill and
    // ONE font size, mirroring the read page. All pills are drawn first so a
    // later bubble never covers an earlier line's wrapped text overflow; text
    // stays per line at the group's shared size.
    final List<(Rect, String, double)> entries = <(Rect, String, double)>[];
    final List<Rect> mergedBackgrounds = <Rect>[];
    for (final RecognizedTextGroup group in groupRecognizedTextBlocks(blocks)) {
      Rect? merged;
      final List<(Rect, String)> groupEntries = <(Rect, String)>[];
      double groupFont = double.infinity;
      for (final int index in group.blockIndices) {
        final RecognizedTextBlock block = blocks[index];
        final Rect rect = Rect.fromLTWH(
          block.left - 4,
          block.top - 3,
          block.width + 8,
          block.height + 6,
        );
        final String translation = translations[index];
        groupEntries.add((rect, translation));
        merged = merged == null ? rect : merged.expandToInclude(rect);
        groupFont = math.min(
          groupFont,
          fitTranslationFontSize(
            translation,
            math.max(1, rect.width - 4),
            rect.height,
            TextDirection.ltr,
          ),
        );
      }
      if (merged != null) {
        mergedBackgrounds.add(merged);
        final double resolved = groupFont.isFinite ? groupFont : 8;
        for (final (Rect rect, String translation) in groupEntries) {
          entries.add((rect, translation, resolved));
        }
      }
    }
    for (final Rect rect in mergedBackgrounds) {
      paintTranslationBubbleBackground(canvas, rect);
    }
    for (final (Rect rect, String translation, double fontSize) in entries) {
      paintTranslationBubbleText(
        canvas,
        rect,
        translation,
        TextDirection.ltr,
        fontSize: fontSize,
      );
    }
    final ui.Image image = await recorder.endRecording().toImage(
      frame.image.width,
      frame.image.height,
    );
    final int width = frame.image.width;
    final int height = frame.image.height;
    // ui.Image cannot cross isolate boundaries, so rasterization (drawImage +
    // toImage, GPU-backed Canvas work) must stay on the UI isolate. The cheap
    // raw-RGBA copy happens here as well; the expensive PNG compression runs
    // on a background isolate so large exports don't jank the UI.
    final ByteData? raw = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    image.dispose();
    if (raw == null)
      throw const ImageTranslationException('OVERLAY_ENCODE_FAILED');
    final Uint8List pngBytes =
        await compute<(Uint8List rgba, int width, int height), Uint8List>(
          _encodePngOverlay,
          (
            raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
            width,
            height,
          ),
        );
    final Directory directory = Directory(
      join(pathService.jhOcrModelDir.path, 'overlays'),
    );
    await directory.create(recursive: true);
    final File output = File(
      join(
        directory.path,
        'translation_${sha256.convert(source).toString().substring(0, 16)}.png',
      ),
    );
    await output.writeAsBytes(pngBytes, flush: true);
    return output;
  }

  /// PNG-encodes raw RGBA pixels on a background isolate (see [exportOverlay]).
  /// The payload is a (rgba, width, height) record; input and output are plain
  /// byte lists so they can cross the isolate boundary. Implements the minimal
  /// PNG container by hand (signature + IHDR + zlib-compressed IDAT + IEND) to
  /// avoid pulling a codec package into the dependency graph.
  static Uint8List _encodePngOverlay(
    (Uint8List rgba, int width, int height) payload,
  ) {
    final (Uint8List rgba, int width, int height) = payload;
    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final ByteData ihdr =
        ByteData(13)
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

  static void _addPngChunk(BytesBuilder builder, String type, List<int> data) {
    final Uint8List typeBytes = ascii.encode(type);
    final Uint8List chunk =
        Uint8List(typeBytes.length + data.length)
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

  /// On-device translation through Apple's Translation framework. Only used in
  /// Apple Live Text mode with the third-party API toggle off; on systems that
  /// do not support it the native side reports TRANSLATION_UNAVAILABLE.
  ///
  /// The OCR reports one block per visual line, so a speech bubble that spans
  /// several lines arrives as several blocks. Apple's framework has no
  /// cross-request context, so each multi-line utterance is folded into ONE
  /// request (its lines joined by newlines) to be translated as a coherent
  /// whole instead of as isolated fragments. Each group's output is then
  /// re-split back into the group's line count so the read-page overlay keeps
  /// a 1:1 mapping between recognized blocks and translated lines; when the
  /// framework cannot translate a group it returns the source unchanged, which
  /// re-splits back into the original lines.
  Future<String> _translateWithApple(List<RecognizedTextBlock> blocks) async {
    // One request per group (its lines joined by newlines) gives the whole
    // utterance cross-line context; the translated group is re-split back into
    // the group's line count afterwards.
    final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(blocks);
    final List<String> groupSources = groups
        .map((RecognizedTextGroup group) => group.textOf(blocks))
        .toList();
    final List<String> rawGroupTexts = await _translateAppleLines(groupSources);
    final List<String> translatedLines = <String>[];
    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final String groupTranslation = groupIndex < rawGroupTexts.length
          ? rawGroupTexts[groupIndex]
          : '';
      final List<String> sourceLines = groups[groupIndex].blockIndices
          .map((int index) => blocks[index].text.trim())
          .toList();
      translatedLines.addAll(
        splitGroupTranslationIntoLines(
          // When the framework cannot translate a group it returns the source
          // unchanged, which re-splits back into the original lines.
          translation: groupTranslation.isEmpty
              ? groupSources[groupIndex]
              : groupTranslation,
          sourceLines: sourceLines,
        ),
      );
    }
    return translatedLines.join('\n');
  }

  /// Translates [lines] through Apple's on-device Translation framework, one
  /// translated string per input line (an input line may itself be a group's
  /// newline-joined text). Throws [ImageTranslationException] when the
  /// framework is unavailable, a language pack is missing, or nothing came
  /// back — callers decide how to fall back.
  Future<List<String>> _translateAppleLines(List<String> lines) async {
    try {
      final Map<dynamic, dynamic>? response = await _liveTextChannel
          .invokeMethod<Map<dynamic, dynamic>>('translateText', {
            'lines': lines,
            'target': _appleTargetLanguage(),
            'source': _appleSourceLanguage(),
          });
      final List<dynamic> rawLines =
          response?['lines'] as List<dynamic>? ?? const [];
      final List<String> translatedLines =
          rawLines.map((line) => line?.toString() ?? '').toList();
      if (translatedLines.join('\n').trim().isEmpty) {
        throw const ImageTranslationException('TRANSLATION_FAILED');
      }
      return translatedLines;
    } on PlatformException catch (e) {
      if (e.code == 'TRANSLATION_UNAVAILABLE') {
        throw const ImageTranslationException('TRANSLATION_UNAVAILABLE');
      }
      if (e.code == 'TRANSLATION_NOT_INSTALLED') {
        log.warning(
          'Apple on-device translation language pack missing: ${e.details}',
        );
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

  String _galleryTextKey(String text) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'text': text,
                'target': imageTranslationSetting.targetLanguage.value,
                'source': imageTranslationSetting.appleLiveTextLanguage.value,
              }),
            ),
          )
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
      () => _runGalleryTextTranslation(key, text, completer),
    );
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
    String key,
    String text,
    Completer<String> completer,
  ) async {
    String result = text;
    try {
      await _ensureGalleryTextCacheLoaded();
      final String? cached = _galleryTextCache[key];
      if (cached != null) {
        result = cached;
      } else if (!_galleryTextFailed.contains(key)) {
        final String translated =
            (await _translateAppleLines(<String>[text])).first;
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
        final Uint8List compressed = await compute(
          _compressJson,
          jsonEncode(_galleryTextCache),
        );
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

  Future<String> _translate(List<RecognizedTextBlock> blocks) async {
    // Multi-line speech bubbles must be translated as one coherent utterance,
    // not line by line: the OCR stage reports one block per visual line, so a
    // bubble that spans several lines arrives as several blocks. Group the
    // blocks into utterances and mark the group boundaries in the source so
    // the model has the full bubble as context while still emitting exactly
    // one translated line per input line for the 1:1 overlay mapping.
    final List<String> sourceLines =
        blocks.map((block) => block.text.trim()).toList();
    final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(blocks);
    final StringBuffer numberedSource = StringBuffer();
    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      numberedSource.writeln('Group ${groupIndex + 1}:');
      for (final int blockIndex in groups[groupIndex].blockIndices) {
        numberedSource.writeln('${blockIndex + 1}: ${sourceLines[blockIndex]}');
      }
    }
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    final CancelToken cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    final ImageTranslationProvider provider =
        imageTranslationSetting.translatorProvider.value;
    final String endpoint = _translationEndpoint(
      imageTranslationSetting.translatorEndpoint.value!,
      provider,
    );
    final String instruction =
        'You translate comic dialogue accurately. The input lines are grouped into numbered groups; each group is one '
        'speech bubble or utterance. Translate each group as a single coherent utterance, combining its line fragments '
        'into natural phrasing. Preserve line order and line count within each group. '
        'Return exactly one translated line per input line, numbered the same as the input (e.g. "1: ..."). '
        'Use continuous numbering across all groups — do not restart the numbers per group. '
        'Do not add headings, group labels, numbering, or reasoning/think blocks.';
    final String prompt =
        'Translate the following comic text into ${imageTranslationSetting.targetLanguage.value}. '
        'Keep the same line numbers:\n\n$numberedSource';
    try {
      if (provider == ImageTranslationProvider.anthropic) {
        final Response<dynamic> response = await dio.post(
          endpoint,
          options: Options(
            headers: _anthropicHeaders(
              imageTranslationSetting.translatorApiKey.value!,
            ),
          ),
          cancelToken: cancelToken,
          data: {
            'model': imageTranslationSetting.translatorModel.value,
            'max_tokens': 2048,
            'system': instruction,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            ...?_thinkingParam(),
          },
        );
        final dynamic blocks =
            response.data is Map ? response.data['content'] : null;
        if (blocks is List) {
          final String content =
              blocks
                  .whereType<Map>()
                  .map((block) => block['text'])
                  .whereType<String>()
                  .join('\n')
                  .trim();
          if (content.isNotEmpty) {
            return _parseNumberedTranslations(
              _stripReasoning(content),
              sourceLines.length,
            ).join('\n');
          }
        }
      } else {
        final Response<dynamic> response = await dio.post(
          endpoint,
          options: Options(
            headers: _openAIHeaders(
              imageTranslationSetting.translatorApiKey.value!,
            ),
          ),
          cancelToken: cancelToken,
          data: {
            'model': imageTranslationSetting.translatorModel.value,
            'temperature': 0.2,
            'messages': [
              {'role': 'system', 'content': instruction},
              {'role': 'user', 'content': prompt},
            ],
            ...?_thinkingParam(),
          },
        );
        final dynamic choices =
            response.data is Map ? response.data['choices'] : null;
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final dynamic message = choices.first['message'];
          final dynamic content = message is Map ? message['content'] : null;
          if (content is String && content.trim().isNotEmpty) {
            return _parseNumberedTranslations(
              _stripReasoning(content.trim()),
              sourceLines.length,
            ).join('\n');
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
      // The group-aware prompt marks speech-bubble boundaries with "Group N:";
      // a model that echoes those labels back must not consume a line slot.
      if (RegExp(r'^\s*group\s*\d+', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final RegExpMatch? match = RegExp(
        r'^\s*(\d+)\s*[:：.]?\s*(.*)$',
      ).firstMatch(line);
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
        'type':
            imageTranslationSetting.enableThinking.value
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
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final Response<dynamic> response = await dio.get(
      _modelsEndpoint(baseUrl, provider),
      options: Options(
        headers:
            provider == ImageTranslationProvider.anthropic
                ? _anthropicHeaders(apiKey)
                : _openAIHeaders(apiKey),
      ),
    );
    final dynamic models = response.data is Map ? response.data['data'] : null;
    if (models is! List) {
      throw const ImageTranslationException('MODELS_INVALID_RESPONSE');
    }
    final List<String> ids =
        models
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

  String _modelsEndpoint(String baseUrl, ImageTranslationProvider provider) =>
      provider == ImageTranslationProvider.anthropic
          ? _appendPath(baseUrl, 'models')
          : _appendPath(baseUrl, 'models');

  String _translationEndpoint(
    String baseUrl,
    ImageTranslationProvider provider,
  ) => _appendPath(
    baseUrl,
    provider == ImageTranslationProvider.anthropic
        ? 'messages'
        : 'chat/completions',
  );

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
        'evicted oldest: $evicted',
      );
      update([taskId(evicted)]);
    }
    update([taskId(cacheKey)]);
  }
}

/// Paints the white rounded pill behind one translated bubble. Drawn for ALL
/// bubbles before any text (see [paintTranslationBubbleText]) so a later
/// bubble never covers an earlier line's wrapped text overflow. Shared by the
/// read-page overlay and the exported overlay PNG so both render identically.
void paintTranslationBubbleBackground(Canvas canvas, Rect rect) {
  final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
  canvas.drawRRect(rrect, Paint()..color = const Color(0xE6FFFFFF));
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke,
  );
}

/// Paints one translated line's text into its bubble [rect], sized to fit both
/// the width and the height of the box so a long translation wraps inside the
/// bubble instead of overflowing it or being chopped by an ellipsis.
///
/// [fontSize] overrides the per-line fit so every line of a merged bubble
/// shares the same size; pass the group's shared size (see
/// [fitTranslationFontSize]).
void paintTranslationBubbleText(
  Canvas canvas,
  Rect rect,
  String translation,
  TextDirection textDirection, {
  double? fontSize,
}) {
  final double maxWidth = math.max(1, rect.width - 4);
  final double maxHeight = rect.height;
  final double resolvedFontSize = fontSize ??
      fitTranslationFontSize(
        translation,
        maxWidth,
        maxHeight,
        textDirection,
      );
  final int maxLines = math.max(
    1,
    (maxHeight / (resolvedFontSize * 1.05)).floor(),
  );
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: translation,
      style: TextStyle(
        color: Colors.black,
        fontSize: resolvedFontSize,
        height: 1.05,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(
    canvas,
    Offset(rect.left + 2, rect.center.dy - painter.height / 2),
  );
}

/// The largest font size (clamped 8-30) whose laid-out wrapped text still fits
/// the box, found with a binary search over [TextPainter] layouts.
double fitTranslationFontSize(
  String text,
  double maxWidth,
  double maxHeight,
  TextDirection textDirection,
) {
  const double minFont = 8;
  const double maxFont = 30;
  double low = minFont;
  double high = maxFont;
  double best = minFont;
  while (low <= high) {
    final double mid = (low + high) / 2;
    final TextPainter probe = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: mid, height: 1.05),
      ),
      textAlign: TextAlign.center,
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    if (probe.height <= maxHeight) {
      best = mid;
      low = mid + 0.5;
    } else {
      high = mid - 0.5;
    }
  }
  return best;
}

class ImageTranslationException implements Exception {
  final String code;

  const ImageTranslationException(this.code);
}
