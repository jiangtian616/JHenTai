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
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';

import '../model/image_translation.dart';
import '../setting/image_translation_setting.dart';
import '../setting/inference_setting.dart';
import 'inference/onnx_model_store.dart';
import 'inference_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';
import '../utils/image_text_grouping.dart';
import '../utils/image_text_container_detection.dart';
import 'engine/engine.dart';

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
    required this.sourceHash,
    required this.sourcePath,
    required this.sourceText,
    required this.blocks,
    this.containers = const <RecognizedTextContainer>[],
    this.mergeTextBlocks = true,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String cacheKey;
  final String persistentKey;
  final String sourceHash;
  final String sourcePath;
  final String sourceText;
  final List<RecognizedTextBlock> blocks;
  final List<RecognizedTextContainer> containers;
  final bool mergeTextBlocks;
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
  int batchSucceeded = 0;
  int batchFailed = 0;
  int batchCanceled = 0;
  int batchSkipped = 0;
  final List<String> batchFailedKeys = <String>[];
  ImageTranslationStage currentStage = ImageTranslationStage.idle;
  bool _cancelRequested = false;

  /// Monotonic batch generation. Bumped every time a batch starts; a stale
  /// batch still unwinding after a cancel can only write shared progress state
  /// when its captured generation is still current, so it can never clobber a
  /// newer batch's banner/progress.
  int _batchGeneration = 0;
  final Set<String> _batchRecordedKeys = <String>{};
  EngineTask<dynamic>? _activeEngineTask;
  String? _activeCacheKey;
  final Map<String, Future<bool>> _hydrateTasks = <String, Future<bool>>{};
  Directory? _translationCacheDirectoryOverride;
  final EngineRegistry engineRegistry = EngineRegistry();

  int beginBatch(int total) {
    _batchGeneration++;
    _cancelRequested = false;
    isBatchTranslating = true;
    batchTotal = total;
    batchCompleted = 0;
    batchSucceeded = 0;
    batchFailed = 0;
    batchCanceled = 0;
    batchSkipped = 0;
    batchFailedKeys.clear();
    _batchRecordedKeys.clear();
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
    currentStage = ImageTranslationStage.done;
    _cancelRequested = false;
    update([batchProgressId]);
  }

  void cancelBatch() {
    _cancelRequested = true;
    final String? activeCacheKey = _activeCacheKey;
    if (activeCacheKey != null) {
      _set(
        activeCacheKey,
        resultFor(activeCacheKey).copyWith(
          status: ImageTranslationStatus.canceled,
          errorMessage: 'CANCELED',
        ),
      );
    }
    _activeEngineTask?.cancel('image translation cancelled');
    _activeEngineTask = null;
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

  void queue(String cacheKey) {
    final ImageTranslationResult current = resultFor(cacheKey);
    if (!current.isTerminal ||
        current.status == ImageTranslationStatus.canceled) {
      _set(cacheKey, current.copyWith(status: ImageTranslationStatus.queued));
    }
  }

  void markDownloading(String cacheKey) {
    _set(
      cacheKey,
      resultFor(cacheKey).copyWith(status: ImageTranslationStatus.downloading),
    );
    _setStage(ImageTranslationStage.downloading);
  }

  void markDownloadError(String cacheKey, String errorMessage) {
    _set(
      cacheKey,
      resultFor(cacheKey).copyWith(
        status: ImageTranslationStatus.downloadError,
        errorMessage: errorMessage,
      ),
    );
  }

  void markOcrError(String cacheKey, String errorMessage) {
    _set(
      cacheKey,
      resultFor(cacheKey).copyWith(
        status: ImageTranslationStatus.ocrError,
        errorMessage: errorMessage,
      ),
    );
  }

  void markNoText(String cacheKey, {int? imageWidth, int? imageHeight}) {
    _set(
      cacheKey,
      resultFor(cacheKey).copyWith(
        status: ImageTranslationStatus.noText,
        errorMessage: 'NO_TEXT',
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      ),
    );
  }

  void markCanceled(String cacheKey, [String errorMessage = 'CANCELED']) {
    _set(
      cacheKey,
      resultFor(cacheKey).copyWith(
        status: ImageTranslationStatus.canceled,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Records a page only after its OCR/translation future has unwound. This
  /// prevents an exception that is logged by a batch caller from looking like
  /// a successful completion.
  void recordBatchResult(String cacheKey, {int? generation}) {
    if (!isBatchTranslating ||
        (generation != null && !isCurrentBatch(generation)) ||
        !_batchRecordedKeys.add(cacheKey)) {
      return;
    }
    final ImageTranslationResult result = resultFor(cacheKey);
    batchCompleted++;
    if (result.status == ImageTranslationStatus.success) {
      batchSucceeded++;
    } else if (result.status == ImageTranslationStatus.canceled) {
      batchCanceled++;
    } else if (result.status == ImageTranslationStatus.noText) {
      batchSkipped++;
    } else if (result.isFailure) {
      batchFailed++;
      if (!batchFailedKeys.contains(cacheKey)) batchFailedKeys.add(cacheKey);
    } else if (result.status == ImageTranslationStatus.idle ||
        result.status == ImageTranslationStatus.queued ||
        result.status == ImageTranslationStatus.downloading ||
        result.status == ImageTranslationStatus.recognizing ||
        result.status == ImageTranslationStatus.translating) {
      batchFailed++;
      if (!batchFailedKeys.contains(cacheKey)) batchFailedKeys.add(cacheKey);
    }
    update([batchProgressId]);
  }

  /// Removes an in-memory result. Used when the source image is reloaded so a
  /// stale overlay is not drawn over the new image.
  void removeResult(String cacheKey) => _removeResult(cacheKey);

  /// Releases only the decoded/paintable in-memory result. Persistent result
  /// files are deliberately untouched so a later viewport entry, a reopened
  /// gallery, or an app restart can hydrate the overlay again.
  void releaseInMemoryResult(String cacheKey) {
    final ImageTranslationResult? current = _results[cacheKey];
    if (current != null && current.isTerminal) {
      _removeResult(cacheKey);
    }
  }

  void _setStage(ImageTranslationStage stage) {
    currentStage = stage;
    update([batchProgressId]);
  }

  String taskId(String cacheKey) => '$taskIdPrefix::$cacheKey';

  Directory get _translationCacheDirectory =>
      _translationCacheDirectoryOverride ??
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

  @visibleForTesting
  Future<String?> persistentKeyForRequest(
    ImageTranslationRequest request,
  ) async {
    final String? imagePath = request.imagePath;
    if (imagePath == null) {
      return null;
    }
    try {
      final List<int> sourceBytes = await File(imagePath).readAsBytes();
      final String imageHash = await compute(_sha256Hex, sourceBytes);
      return _persistentCacheKey(request, imageHash);
    } on FileSystemException {
      return null;
    }
  }

  @visibleForTesting
  void setTranslationCacheDirectoryForTesting(Directory? directory) {
    _translationCacheDirectoryOverride = directory;
  }

  @visibleForTesting
  Future<String?> legacyPersistentKeyForRequest(
    ImageTranslationRequest request, {
    int promptVersion = 2,
  }) async {
    final String? imagePath = request.imagePath;
    if (imagePath == null) return null;
    try {
      final List<int> sourceBytes = await File(imagePath).readAsBytes();
      final String imageHash = await compute(_sha256Hex, sourceBytes);
      return _persistentCacheKey(
        request,
        imageHash,
        promptVersion: promptVersion,
        legacy: true,
      );
    } on FileSystemException {
      return null;
    }
  }

  @visibleForTesting
  Future<void> writePersistentResultForRequest(
    ImageTranslationRequest request,
    ImageTranslationResult result,
  ) async {
    final String? key = await persistentKeyForRequest(request);
    if (key == null) {
      throw ArgumentError.value(
        request.imagePath,
        'request.imagePath',
        'Image path is required to persist a translation result.',
      );
    }
    await _writePersistentResult(key, result);
  }

  @visibleForTesting
  Future<void> writePersistentResultForKeyForTesting(
    String key,
    ImageTranslationResult result,
  ) => _writePersistentResult(key, result);

  @visibleForTesting
  void setResultForTesting(String cacheKey, ImageTranslationResult result) {
    _set(cacheKey, result);
  }

  /// Publishes a result produced by an independent pipeline while keeping the
  /// existing overlay/GetX notification path. Context translation uses this
  /// instead of reaching into the service's result map.
  void publishResult(String cacheKey, ImageTranslationResult result) {
    _set(cacheKey, result);
  }

  /// Context batches use a cache key that is different from the ordinary
  /// single-page key. These narrow methods keep the existing gzip cache and
  /// hydrate behavior as the single persistence implementation.
  Future<ImageTranslationResult?> readPersistentResultForKey(String key) =>
      _readPersistentResult(key);

  Future<void> writePersistentResultForKey(
    String key,
    ImageTranslationResult result,
  ) => _writePersistentResult(key, result);

  Future<bool> hydratePersistentResult({
    required String displayCacheKey,
    required String persistentKey,
  }) async {
    final ImageTranslationResult? result = await _readPersistentResult(
      persistentKey,
    );
    if (result == null) return false;
    _set(displayCacheKey, result.copyWith(fromCache: true));
    return true;
  }

  /// Allows an independent batch orchestrator to participate in the existing
  /// cancel button. The concrete engine remains owned by its adapter.
  void attachExternalBatchTask(
    EngineTask<dynamic> task, {
    String? activeCacheKey,
  }) {
    _activeEngineTask = task;
    _activeCacheKey = activeCacheKey;
  }

  void detachExternalBatchTask(EngineTask<dynamic> task) {
    if (identical(_activeEngineTask, task)) {
      _activeEngineTask = null;
      _activeCacheKey = null;
    }
  }

  void setBatchStage(ImageTranslationStage stage) => _setStage(stage);

  Future<bool> hydrateResult(ImageTranslationRequest request) {
    final ImageTranslationResult current = resultFor(request.cacheKey);
    if (current.status == ImageTranslationStatus.success ||
        current.status == ImageTranslationStatus.recognizing ||
        current.status == ImageTranslationStatus.translating) {
      return Future.value(current.status == ImageTranslationStatus.success);
    }
    final Future<bool>? existing = _hydrateTasks[request.cacheKey];
    if (existing != null) {
      return existing;
    }
    final Future<bool> task = _hydrateResultInternal(request);
    _hydrateTasks[request.cacheKey] = task;
    return task.whenComplete(() {
      if (identical(_hydrateTasks[request.cacheKey], task)) {
        _hydrateTasks.remove(request.cacheKey);
      }
    });
  }

  /// OCR stage of a translation: reads the image, runs recognition and returns
  /// the recognized source for the translation stage. Returns null when the
  /// page should be skipped (already translated / image unavailable / no text).
  /// Split from [translate] so the batch pipeline can overlap the next page's
  /// OCR with the current page's translation.
  Future<RecognizedImage?> recognizeImage(
    ImageTranslationRequest request, {
    bool force = false,
  }) async {
    final String? imagePath = request.imagePath;
    if (imagePath == null) {
      if (resultFor(request.cacheKey).status !=
          ImageTranslationStatus.downloadError) {
        markDownloadError(request.cacheKey, 'IMAGE_SOURCE_UNAVAILABLE');
      }
      return null;
    }
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
    _activeCacheKey = request.cacheKey;

    late final Uint8List sourceBytes;
    try {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      // Read the image bytes exactly once: they feed the persistent-cache
      // hash and the image-dimension fallback probe.
      sourceBytes = await File(imagePath).readAsBytes();

      // Hashing the full image on the UI isolate drops frames on every page
      // (SHA-256 over a few MB is tens of ms); run it off-isolate. The single
      // hash names the persistent cache entry as well.
      final String imageHash = await compute(_sha256Hex, sourceBytes);
      final String persistentKey = _persistentCacheKey(request, imageHash);
      final ImageTranslationResult? cached = await _readPersistentResultForHash(
        request,
        imageHash,
      );
      if (!force && cached != null) {
        _set(request.cacheKey, cached.copyWith(fromCache: true));
        return null;
      }

      // Bubble detection is deliberately started before OCR.  OCR still runs
      // on the complete page (the PP-OCRv6 adapter has no region-aware
      // recognizer yet), while the resulting boxes are joined to OCR lines
      // below.  This keeps the user-visible order deterministic and leaves a
      // safe full-page OCR fallback when the optional model is unavailable.
      final bool useBubbleDetection =
          imageTranslationSetting.autoMergeText.value &&
          imageTranslationSetting.enableBubbleDetection.value;
      final DetectionResult? bubbleDetection =
          useBubbleDetection ? await _detectBubbleRegions(imagePath) : null;
      final _RecognizeResult recognized = await _recognize(imagePath);
      final List<RecognizedTextBlock> blocks = recognized.blocks;
      final bool mergeTextBlocks = imageTranslationSetting.autoMergeText.value;
      // Resolve the source dimensions before accepting detector rectangles so
      // a page-sized false positive can never become a layout container.
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
      List<RecognizedTextContainer> containers =
          useBubbleDetection
              ? _containersFromBubbleDetection(
                blocks,
                bubbleDetection,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
              )
              : const <RecognizedTextContainer>[];
      if (useBubbleDetection && containers.isEmpty) {
        containers = await _detectTextContainers(sourceBytes, blocks);
      }
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      final String sourceText = blocks
          .map((block) => block.text)
          .where((text) => text.isNotEmpty)
          .join('\n');
      if (sourceText.isEmpty) {
        markNoText(
          request.cacheKey,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
        return null;
      }

      final bool usesLocalTranslation =
          imageTranslationSetting.translatorEngine.value ==
          ImageTranslationEngine.localGguf;
      if (!imageTranslationSetting.usesAppleOnDeviceTranslation &&
          !usesLocalTranslation &&
          !imageTranslationSetting.isTranslatorConfigured) {
        _set(
          request.cacheKey,
          ImageTranslationResult(
            status: ImageTranslationStatus.failed,
            sourceText: sourceText,
            blocks: blocks,
            containers: containers,
            mergeTextBlocks: mergeTextBlocks,
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
          containers: containers,
          mergeTextBlocks: mergeTextBlocks,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
      );
      _setStage(ImageTranslationStage.translating);
      return RecognizedImage(
        cacheKey: request.cacheKey,
        persistentKey: persistentKey,
        sourceHash: imageHash,
        sourcePath: imagePath,
        sourceText: sourceText,
        blocks: blocks,
        containers: containers,
        mergeTextBlocks: mergeTextBlocks,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    } on ImageTranslationException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      log.warning('Image translation failed: ${e.code}');
      if (e.code == 'OCR_CANCELLED') {
        markCanceled(request.cacheKey, e.code);
      } else if (e.code == 'NO_TEXT') {
        markNoText(request.cacheKey);
      } else if (e.code.startsWith('OCR_')) {
        markOcrError(request.cacheKey, e.code);
      } else {
        _set(
          request.cacheKey,
          resultFor(request.cacheKey).copyWith(
            status: ImageTranslationStatus.failed,
            errorMessage: e.code,
          ),
        );
      }
      log.trace(stack);
    } on ProcessException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      log.warning('Image OCR executable is unavailable: ${e.executable}');
      markOcrError(request.cacheKey, 'OCR_UNAVAILABLE');
      log.trace(stack);
    } on TimeoutException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      markOcrError(request.cacheKey, 'OCR_TIMEOUT');
      log.warning('Image OCR timed out: $e');
      log.trace(stack);
    } on FileSystemException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      markDownloadError(request.cacheKey, 'IMAGE_SOURCE_UNAVAILABLE');
      log.warning('Image source is unavailable: $e');
      log.trace(stack);
    } catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return null;
      }
      log.error('Image translation failed', e, stack);
      markOcrError(request.cacheKey, 'OCR_FAILED');
    } finally {
      // The source buffer is method-scoped and is never stored in the result or
      // read-page state, so it becomes collectible when this attempt unwinds.
      if (_activeCacheKey == request.cacheKey) {
        _activeCacheKey = null;
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
    _activeCacheKey = request.cacheKey;
    final TranslationEngine engine = engineRegistry.selectedTranslation;
    EngineTask<TranslationResult>? task;
    try {
      await engine.ensureReady();
      final EngineCapabilityDecision capability =
          engineRegistry.evaluateSelected();
      if (!capability.supported) {
        throw ImageTranslationException(
          capability.reason.contains('not ready')
              ? 'ENGINE_NOT_READY'
              : 'UNSUPPORTED_COMBINATION',
        );
      }
      final EngineTask<TranslationResult> activeTask = engine.translate(
        TranslationEngineRequest(
          blocks: recognized.blocks,
          imagePath: recognized.sourcePath,
          targetLanguage:
              engine.descriptor.id == 'apple-translation'
                  ? _appleTargetLanguage()
                  : imageTranslationSetting.targetLanguage.value,
          sourceLanguage: _appleSourceLanguage(),
          mergeTextBlocks: recognized.mergeTextBlocks,
          containers: recognized.containers,
          configuration: <String, dynamic>{
            'provider': imageTranslationSetting.translatorProvider.value.name,
            'model':
                imageTranslationSetting.translatorEngine.value ==
                        ImageTranslationEngine.localGguf
                    ? imageTranslationSetting.localModelId.value
                    : imageTranslationSetting.translatorModel.value,
            'thinking': imageTranslationSetting.enableThinking.value,
          },
          // Group-level translation is a semantic prompt change. Bumping the
          // version prevents old line-by-line results from being reused as if
          // they had been produced by the new bubble-aware contract.
          promptVersion: 4,
        ),
      );
      task = activeTask;
      _activeEngineTask = activeTask;
      _setStage(ImageTranslationStage.translating);
      final TranslationResult translation = await activeTask.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          activeTask.cancel('translation timeout');
          throw const ImageTranslationException('TRANSLATION_TIMEOUT');
        },
      );
      final String translatedText = translation.translatedText;
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
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
          translatedGroups: translation.groupTranslations,
          blocks: recognized.blocks,
          containers: recognized.containers,
          mergeTextBlocks: recognized.mergeTextBlocks,
          imageWidth: recognized.imageWidth,
          imageHeight: recognized.imageHeight,
        ),
      );
      try {
        await _writePersistentResult(
          recognized.persistentKey,
          resultFor(request.cacheKey),
        );
      } on FileSystemException catch (e, stack) {
        // The visible result is already complete. A cache write failure must
        // be reported in logs without converting a successful translation
        // into a false translation failure.
        log.warning('Failed to persist image translation: $e');
        log.trace(stack);
      }
      _setStage(ImageTranslationStage.done);
    } on ImageTranslationException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return;
      }
      log.warning('Image translation failed: ${e.code}');
      _set(
        request.cacheKey,
        resultFor(
          request.cacheKey,
        ).copyWith(status: ImageTranslationStatus.failed, errorMessage: e.code),
      );
      log.trace(stack);
    } on EngineTaskCancelledException {
      markCanceled(request.cacheKey);
    } on EngineException catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
        return;
      }
      final String code = switch (e.code) {
        'not_ready' => 'ENGINE_NOT_READY',
        'unsupported_platform' => 'UNSUPPORTED_COMBINATION',
        'invalid_response' => 'TRANSLATION_INVALID_RESPONSE',
        'request_failed' => 'TRANSLATION_REQUEST_FAILED',
        'timeout' => 'TRANSLATION_TIMEOUT',
        'translation_unavailable' => 'TRANSLATION_UNAVAILABLE',
        'translation_not_installed' => 'TRANSLATION_NOT_INSTALLED',
        _ => 'TRANSLATION_FAILED',
      };
      _set(
        request.cacheKey,
        resultFor(
          request.cacheKey,
        ).copyWith(status: ImageTranslationStatus.failed, errorMessage: code),
      );
      log.warning('Image translation engine failed: $e');
      log.trace(stack);
    } catch (e, stack) {
      if (_cancelRequested) {
        markCanceled(request.cacheKey);
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
    } finally {
      if (task != null && identical(_activeEngineTask, task)) {
        _activeEngineTask = null;
      }
      if (_activeCacheKey == request.cacheKey) {
        _activeCacheKey = null;
      }
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
    String imageHash, {
    int promptVersion = 4,
    bool legacy = false,
  }) {
    final String configFingerprint = _translationConfigFingerprint(
      promptVersion: promptVersion,
      legacy: legacy,
    );
    if (legacy) {
      return sha256
          .convert(utf8.encode('$imageHash:$configFingerprint'))
          .toString();
    }
    final Map<String, dynamic> configuration =
        jsonDecode(configFingerprint) as Map<String, dynamic>;
    return EngineCacheKey(
      sourceHash: imageHash,
      ocrModel:
          configuration['onnxModel'] as String? ??
          configuration['ocrEngine'] as String?,
      ocrConfiguration: <String, dynamic>{
        'engine': configuration['ocrEngine'],
        'language': configuration['appleLanguage'],
        'backend': configuration['onnxBackend'],
        'mangaAutoSuggest': imageTranslationSetting.mangaOcrAutoSuggest.value,
        'bubbleDetection': configuration['bubbleDetection'],
        'bubbleModel': configuration['bubbleModel'],
      },
      translationModel: configuration['model'] as String?,
      translationConfiguration: <String, dynamic>{
        'engine': configuration['translatorEngine'],
        'provider': configuration['provider'],
        'endpoint': configuration['endpoint'],
        'target': configuration['target'],
        'thinking': imageTranslationSetting.enableThinking.value,
        'mergeTextBlocks': imageTranslationSetting.autoMergeText.value,
      },
      promptVersion: promptVersion,
      // v3 adds speech-bubble model identity to the cache key.  A result
      // generated before/after toggling bubble detection has different
      // container geometry and must never be reused for the other mode.
      pipelineVersion: 'image-translation-v3',
    ).value;
  }

  String _translationConfigFingerprint({
    int promptVersion = 4,
    bool legacy = false,
  }) {
    if (legacy) {
      final Map<String, dynamic> oldFingerprint = {
        'ocrEngine': imageTranslationSetting.ocrEngine.value.name,
        'ocrLanguage': 'jpn+eng',
        'paddleLanguage': 'japan',
        'appleLanguage': imageTranslationSetting.appleLiveTextLanguage.value,
        'appleUseApi':
            imageTranslationSetting.appleLiveTextUseThirdPartyApi.value,
        'mangaOcrAutoSuggest':
            imageTranslationSetting.mangaOcrAutoSuggest.value,
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
        'promptVersion': promptVersion,
      };
      return jsonEncode(oldFingerprint);
    }
    return jsonEncode({
      'ocrEngine': imageTranslationSetting.ocrEngine.value.name,
      'appleLanguage': imageTranslationSetting.appleLiveTextLanguage.value,
      'appleUseApi':
          imageTranslationSetting.appleLiveTextUseThirdPartyApi.value,
      'mangaOcrAutoSuggest': imageTranslationSetting.mangaOcrAutoSuggest.value,
      'bubbleDetection': imageTranslationSetting.enableBubbleDetection.value,
      'bubbleModel': imageTranslationSetting.enableBubbleDetection.value
          ? OnnxModelStore.instance.fingerprintOf(
              OnnxModelStore.bubbleSegmentationManifestId,
            )
          : null,
      if (imageTranslationSetting.ocrEngine.value == ImageOcrEngine.onnx) ...{
        'onnxModel': OnnxModelStore.instance.fingerprintOf(
          imageTranslationSetting.onnxModelId.value,
        ),
        'onnxBackend':
            inferenceService.resolveBackendFor(InferenceDomain.ocr)?.name,
      },
      'provider': imageTranslationSetting.translatorProvider.value.name,
      'translatorEngine': imageTranslationSetting.translatorEngine.value.name,
      'endpoint': imageTranslationSetting.translatorEndpoint.value,
      'model':
          imageTranslationSetting.translatorEngine.value ==
                  ImageTranslationEngine.localGguf
              ? imageTranslationSetting.localModelId.value
              : imageTranslationSetting.translatorModel.value,
      'target': imageTranslationSetting.targetLanguage.value,
      'mergeTextBlocks': imageTranslationSetting.autoMergeText.value,
      // Group-aware translation (speech bubbles translated as one utterance).
      'promptVersion': promptVersion,
    });
  }

  /// Removes reasoning markers before a result is persisted or embedded. The
  /// API adapter also sanitizes its response, while this boundary keeps old
  /// cache files safe when they are hydrated through the service.
  List<String> _persistentCacheKeysForHash(
    ImageTranslationRequest request,
    String imageHash,
  ) {
    final String current = _persistentCacheKey(request, imageHash);
    final List<String> candidates = <String>[
      current,
      _persistentCacheKey(request, imageHash, promptVersion: 2, legacy: true),
      _persistentCacheKey(request, imageHash, promptVersion: 1, legacy: true),
    ];
    return candidates.toSet().toList();
  }

  Future<ImageTranslationResult?> _readPersistentResultForHash(
    ImageTranslationRequest request,
    String imageHash,
  ) async {
    final List<String> keys = _persistentCacheKeysForHash(request, imageHash);
    final String currentKey = keys.first;
    for (final String key in keys) {
      final ImageTranslationResult? cached = await _readPersistentResult(key);
      if (cached == null) continue;
      // Prompt version 4 translates one speech-bubble group at a time. Older
      // entries only contain line-by-line output, which would reintroduce the
      // fragmentary layout this cache version is intended to fix.
      if (key != currentKey && cached.translatedGroups.isEmpty) {
        continue;
      }
      if (key != currentKey &&
          cached.mergeTextBlocks !=
              imageTranslationSetting.autoMergeText.value) {
        continue;
      }
      if (key != currentKey) {
        try {
          await _writePersistentResult(currentKey, cached);
        } on FileSystemException catch (e, stack) {
          log.warning('Failed to migrate image translation cache: $e');
          log.trace(stack);
        }
      }
      return cached;
    }
    return null;
  }

  Future<bool> _hydrateResultInternal(ImageTranslationRequest request) async {
    final String? imagePath = request.imagePath;
    if (imagePath == null) {
      return false;
    }
    final Uint8List sourceBytes;
    try {
      sourceBytes = await File(imagePath).readAsBytes();
    } on FileSystemException {
      return false;
    }
    final String imageHash = await compute(_sha256Hex, sourceBytes);
    final ImageTranslationResult? cached = await _readPersistentResultForHash(
      request,
      imageHash,
    );
    if (cached == null) {
      return false;
    }
    _set(request.cacheKey, cached.copyWith(fromCache: true));
    return true;
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

  String _stripReasoning(String text) =>
      text
          .replaceAllMapped(
            RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
            (_) => '',
          )
          .replaceAllMapped(
            RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
            (_) => '',
          )
          .replaceAllMapped(
            RegExp(r'\[/?reasoning\]', caseSensitive: false),
            (_) => '',
          )
          .replaceAll(RegExp(r'\n\s*\n+'), '\n')
          .trim();

  Future<void> _writePersistentResult(
    String key,
    ImageTranslationResult result,
  ) async {
    if (result.status != ImageTranslationStatus.success) {
      return;
    }
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
    final OcrEngine engine = engineRegistry.selectedOcr;
    final EngineTask<OcrResult> task = engine.recognize(
      OcrEngineRequest(
        imagePath: imagePath,
        configuration: <String, dynamic>{
          'language': imageTranslationSetting.appleLiveTextLanguage.value,
        },
      ),
    );
    _activeEngineTask = task;
    try {
      _setStage(ImageTranslationStage.recognizing);
      final OcrResult result = await task.future.timeout(
        const Duration(minutes: 2),
      );
      return (
        blocks: result.blocks,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
      );
    } on EngineTaskCancelledException {
      throw const ImageTranslationException('OCR_CANCELLED');
    } on EngineException catch (error) {
      if (error.code == 'not_ready') {
        throw const ImageTranslationException('OCR_NOT_CONFIGURED');
      }
      throw ImageTranslationException(
        error.code == 'unsupported_platform'
            ? 'OCR_UNSUPPORTED_PLATFORM'
            : error.code == 'no_text'
            ? 'NO_TEXT'
            : 'OCR_FAILED',
      );
    } on TimeoutException {
      task.cancel('image translation OCR timeout');
      throw const ImageTranslationException('OCR_TIMEOUT');
    } finally {
      if (identical(_activeEngineTask, task)) _activeEngineTask = null;
    }
  }

  Future<List<RecognizedTextContainer>> _detectTextContainers(
    Uint8List sourceBytes,
    List<RecognizedTextBlock> blocks,
  ) async {
    if (blocks.length < 2) {
      return const <RecognizedTextContainer>[];
    }
    try {
      final List<Map<String, dynamic>> raw =
          await compute(detectTextContainersFromBytes, <String, dynamic>{
            'bytes': sourceBytes,
            'blocks':
                blocks
                    .map((RecognizedTextBlock block) => block.toJson())
                    .toList(),
          });
      return raw
          .map(
            (Map<String, dynamic> json) =>
                RecognizedTextContainer.fromJson(json),
          )
          .toList(growable: false);
    } catch (error, stack) {
      log.warning('Text-container detection skipped: $error');
      log.trace(stack);
      return const <RecognizedTextContainer>[];
    }
  }

  Future<DetectionResult?> _detectBubbleRegions(String imagePath) async {
    final DetectionEngine? detector = engineRegistry.findDetection(
      'manga109-bubble-segmentation',
    );
    if (detector == null || !detector.isReady) {
      return null;
    }
    final EngineTask<DetectionResult> task = detector.detect(
      EngineImageRequest(imagePath: imagePath),
    );
    try {
      return await task.future.timeout(const Duration(minutes: 2));
    } catch (error, stack) {
      log.warning('Manga109 bubble detection skipped: $error');
      log.trace(stack);
      return null;
    }
  }

  List<RecognizedTextContainer> _containersFromBubbleDetection(
    List<RecognizedTextBlock> blocks,
    DetectionResult? detection, {
    required int imageWidth,
    required int imageHeight,
  }) {
    if (blocks.isEmpty || detection == null) {
      return const <RecognizedTextContainer>[];
    }
    final List<RecognizedTextContainer> containers =
        <RecognizedTextContainer>[];
    for (final DetectedTextRegion region in detection.regions) {
      if (imageWidth <= 0 ||
          imageHeight <= 0 ||
          region.width >= imageWidth * 0.95 ||
          region.height >= imageHeight * 0.95 ||
          region.width * region.height >= imageWidth * imageHeight * 0.8) {
        continue;
      }
      final List<int> indices = <int>[];
      for (int blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
        final RecognizedTextBlock block = blocks[blockIndex];
        final double centerX = block.left + block.width / 2;
        final double centerY = block.top + block.height / 2;
        if (centerX >= region.left &&
            centerX <= region.left + region.width &&
            centerY >= region.top &&
            centerY <= region.top + region.height) {
          indices.add(blockIndex);
        }
      }
      if (indices.isNotEmpty) {
        containers.add(
          RecognizedTextContainer(
            blockIndices: indices,
            left: region.left,
            top: region.top,
            width: region.width,
            height: region.height,
            confidence: region.confidence,
          ),
        );
      }
    }
    return containers;
  }

  Future<File> exportOverlay(ImageTranslationRequest request) async {
    final String? imagePath = request.imagePath;
    if (imagePath == null) {
      throw const ImageTranslationException('IMAGE_SOURCE_UNAVAILABLE');
    }
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
      await File(imagePath).readAsBytes(),
    );
    final ui.Codec codec = await ui.instantiateImageCodec(source);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..drawImage(frame.image, Offset.zero, Paint());
    // Render each detected speech bubble as one text layout. The old renderer
    // painted every OCR line into its own narrow rect, which made a natural
    // translation wrap into tiny, disconnected fragments. A merged rect lets
    // TextPainter choose one readable size for the whole utterance.
    final List<(Rect, String, double)> entries = <(Rect, String, double)>[];
    final List<Rect> mergedBackgrounds = <Rect>[];
    // Container indices are generated against the complete OCR list. If an
    // old cache contains zero-sized blocks that are filtered above, discard
    // the explicit container geometry for this export rather than applying a
    // box to the wrong group; the OCR-group fallback remains safe.
    final List<RecognizedTextContainer> containers =
        blocks.length == result.blocks.length
            ? result.containers
            : const <RecognizedTextContainer>[];
    final List<RecognizedTextGroup> groups = translationTextGroups(
      blocks,
      merge: result.mergeTextBlocks,
      containers: containers,
    );
    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final RecognizedTextGroup group = groups[groupIndex];
      Rect? merged;
      final List<String> groupLines = <String>[];
      for (final int index in group.blockIndices) {
        groupLines.add(index < translations.length ? translations[index] : '');
        if (merged == null) {
          final RecognizedTextGroupRenderBounds? detected =
              explicitRenderBoundsForRecognizedTextGroup(group, containers);
          final RecognizedTextGroupRenderBounds bounds =
              detected ?? renderBoundsForRecognizedTextGroup(group, blocks);
          merged = Rect.fromLTRB(
            bounds.left - 4,
            bounds.top - 3,
            bounds.right + 4,
            bounds.bottom + 3,
          );
        }
      }
      if (merged != null) {
        final Rect? safeRect = safeTranslationBackgroundRect(
          merged,
          Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
        );
        if (safeRect == null) {
          continue;
        }
        mergedBackgrounds.add(safeRect);
        final String translation =
            groupIndex < result.translatedGroups.length &&
                    result.translatedGroups[groupIndex].trim().isNotEmpty
                ? result.translatedGroups[groupIndex].trim()
                : groupLines.join('\n');
        final double resolved = fitTranslationFontSize(
          translation,
          math.max(1, safeRect.width - 8),
          math.max(1, safeRect.height - 4),
          TextDirection.ltr,
        );
        entries.add((safeRect, translation, resolved));
      }
    }
    for (final Rect rect in mergedBackgrounds) {
      paintTranslationBubbleBackground(
        canvas,
        rect,
        color: imageTranslationSetting.translationBackgroundColor.value,
        opacity: imageTranslationSetting.translationBackgroundOpacity.value,
      );
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
  Future<List<String>> _translateAppleLines(List<String> lines) async {
    final TranslationEngine engine =
        engineRegistry.findTranslation('apple-translation')!;
    final List<RecognizedTextBlock> blocks = lines
        .map(
          (String line) => RecognizedTextBlock(
            text: line,
            confidence: 1,
            width: 1,
            height: 1,
          ),
        )
        .toList(growable: false);
    try {
      final TranslationResult result =
          await engine
              .translate(
                TranslationEngineRequest(
                  blocks: blocks,
                  targetLanguage: _appleTargetLanguage(),
                  // Gallery title/comment auto-translation always lets the native
                  // side auto-detect the source language. The Apple Live Text
                  // recognition-language picker is an OCR/translation hint for the
                  // image path, not a hard constraint for free-text translation.
                  sourceLanguage: null,
                ),
              )
              .future;
      return result.lines;
    } on EngineException catch (error) {
      throw ImageTranslationException(switch (error.code) {
        'translation_unavailable' => 'TRANSLATION_UNAVAILABLE',
        'translation_not_installed' => 'TRANSLATION_NOT_INSTALLED',
        _ => 'TRANSLATION_FAILED',
      });
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
Rect? safeTranslationBackgroundRect(Rect rect, Size canvasSize) {
  if (!rect.left.isFinite ||
      !rect.top.isFinite ||
      !rect.right.isFinite ||
      !rect.bottom.isFinite ||
      rect.width <= 0 ||
      rect.height <= 0 ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    return null;
  }
  final Rect clipped = rect.intersect(Offset.zero & canvasSize);
  if (clipped.width <= 0 || clipped.height <= 0) {
    return null;
  }
  // A malformed detector/OCR rectangle must not become a page-sized backing
  // plate over the complete translated image.
  if (clipped.width >= canvasSize.width * 0.95 &&
      clipped.height >= canvasSize.height * 0.95) {
    return null;
  }
  return clipped;
}

void paintTranslationBubbleBackground(
  Canvas canvas,
  Rect rect, {
  Color? color,
  double? opacity,
}) {
  final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
  final Color configured =
      color ?? imageTranslationSetting.translationBackgroundColor.value;
  final int alpha = ((opacity ??
              imageTranslationSetting.translationBackgroundOpacity.value) *
          255)
      .round()
      .clamp(0, 255);
  canvas.drawRRect(rrect, Paint()..color = configured.withAlpha(alpha));
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke,
  );
}

/// Paints one translated utterance into its bubble [rect], sized to fit both
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
  final double resolvedFontSize =
      fontSize ??
      fitTranslationFontSize(translation, maxWidth, maxHeight, textDirection);
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
      text: TextSpan(text: text, style: TextStyle(fontSize: mid, height: 1.05)),
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
