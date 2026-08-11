import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../model/image_translation.dart';
import 'engine/context_translation_contract.dart';
import 'engine/engine_contract.dart';
import 'image_translation_service.dart';

class ContextTranslationPageLine {
  const ContextTranslationPageLine({required this.lineId, required this.block});

  final String lineId;
  final RecognizedTextBlock block;

  ContextTranslationLineRequest toRequest(String pageId) =>
      ContextTranslationLineRequest(
        pageId: pageId,
        lineId: lineId,
        sourceText: block.text.trim(),
      );
}

/// OCR output prepared for a context request. [pageId] and [lineId] are
/// explicit protocol identifiers; they are not inferred from response order.
class ContextTranslationPage {
  const ContextTranslationPage({
    required this.pageId,
    required this.displayCacheKey,
    required this.sourceHash,
    required this.pageHash,
    required this.sourceText,
    required this.imageWidth,
    required this.imageHeight,
    required this.lines,
    this.sourcePath = '',
  });

  factory ContextTranslationPage.fromBlocks({
    required String pageId,
    required String displayCacheKey,
    required String sourceHash,
    required List<RecognizedTextBlock> blocks,
    required String sourceText,
    required int imageWidth,
    required int imageHeight,
    String sourcePath = '',
  }) {
    final Map<String, int> occurrences = <String, int>{};
    final List<ContextTranslationPageLine> lines =
        <ContextTranslationPageLine>[];
    for (final RecognizedTextBlock block in blocks) {
      final String fingerprint = sha256
          .convert(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'text': block.text.trim(),
                'left': block.left,
                'top': block.top,
                'width': block.width,
                'height': block.height,
              }),
            ),
          )
          .toString()
          .substring(0, 16);
      final int occurrence = (occurrences[fingerprint] ?? 0) + 1;
      occurrences[fingerprint] = occurrence;
      lines.add(
        ContextTranslationPageLine(
          lineId: 'line-$fingerprint-$occurrence',
          block: block,
        ),
      );
    }
    return ContextTranslationPage(
      pageId: pageId,
      displayCacheKey: displayCacheKey,
      sourceHash: sourceHash,
      pageHash: _contextPageHash(sourceHash, lines),
      sourceText: sourceText,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      lines: List<ContextTranslationPageLine>.unmodifiable(lines),
      sourcePath: sourcePath,
    );
  }

  factory ContextTranslationPage.fromRecognizedImage({
    required String pageId,
    required ImageTranslationRequest request,
    required RecognizedImage recognized,
  }) => ContextTranslationPage.fromBlocks(
    pageId: pageId,
    displayCacheKey: request.cacheKey,
    sourceHash: recognized.sourceHash,
    blocks: recognized.blocks,
    sourceText: recognized.sourceText,
    imageWidth: recognized.imageWidth,
    imageHeight: recognized.imageHeight,
    sourcePath: recognized.sourcePath,
  );

  final String pageId;
  final String displayCacheKey;
  final String sourceHash;
  final String pageHash;
  final String sourceText;
  final int imageWidth;
  final int imageHeight;
  final List<ContextTranslationPageLine> lines;
  final String sourcePath;

  List<RecognizedTextBlock> get blocks =>
      lines.map((line) => line.block).toList(growable: false);

  ContextTranslationPageRequest toRequest() => ContextTranslationPageRequest(
    pageId: pageId,
    pageHash: pageHash,
    lines: lines.map((line) => line.toRequest(pageId)).toList(growable: false),
  );
}

String _contextPageHash(
  String sourceHash,
  List<ContextTranslationPageLine> lines,
) {
  final Map<String, dynamic> payload = <String, dynamic>{
    'sourceHash': sourceHash,
    'lines': lines
        .map(
          (line) => <String, dynamic>{
            'lineId': line.lineId,
            'text': line.block.text.trim(),
            'left': line.block.left,
            'top': line.block.top,
            'width': line.block.width,
            'height': line.block.height,
          },
        )
        .toList(growable: false),
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}

class ContextTranslationBatch {
  const ContextTranslationBatch({
    required this.pages,
    required this.batchSize,
    required this.modelVersion,
    required this.promptVersion,
    required this.targetLanguage,
    required this.ocrConfiguration,
    this.sourceLanguage,
    this.configuration = const <String, dynamic>{},
  });

  final List<ContextTranslationPage> pages;
  final ContextBatchSize batchSize;
  final String modelVersion;
  final int promptVersion;
  final String targetLanguage;
  final String? sourceLanguage;
  final Map<String, dynamic> ocrConfiguration;
  final Map<String, dynamic> configuration;

  ContextTranslationCacheKey get cacheKey => ContextTranslationCacheKey(
    contextPageHashes: pages
        .map((page) => page.pageHash)
        .toList(growable: false),
    batchSize: batchSize,
    modelVersion: modelVersion,
    promptVersion: promptVersion,
    targetLanguage: targetLanguage,
    sourceLanguage: sourceLanguage,
    ocrConfiguration: ocrConfiguration,
    translationConfiguration: configuration,
  );

  ContextTranslationEngineRequest toEngineRequest(List<String> targetPageIds) =>
      ContextTranslationEngineRequest(
        pages: pages.map((page) => page.toRequest()).toList(growable: false),
        batchSize: batchSize,
        targetPageIds: targetPageIds,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
        ocrConfiguration: ocrConfiguration,
        configuration: configuration,
      );

  static List<List<T>> partition<T>(List<T> values, ContextBatchSize size) {
    if (values.isEmpty) {
      return <List<T>>[];
    }
    final List<List<T>> result = <List<T>>[];
    for (int offset = 0; offset < values.length; offset += size.pageCount) {
      final int end = (offset + size.pageCount).clamp(0, values.length);
      result.add(List<T>.unmodifiable(values.sublist(offset, end)));
    }
    return List<List<T>>.unmodifiable(result);
  }
}

class ContextTranslationCacheKey {
  const ContextTranslationCacheKey({
    required this.contextPageHashes,
    required this.batchSize,
    required this.modelVersion,
    required this.promptVersion,
    required this.targetLanguage,
    required this.ocrConfiguration,
    this.translationConfiguration = const <String, dynamic>{},
    this.sourceLanguage,
  });

  final List<String> contextPageHashes;
  final ContextBatchSize batchSize;
  final String modelVersion;
  final int promptVersion;
  final String targetLanguage;
  final String? sourceLanguage;
  final Map<String, dynamic> ocrConfiguration;
  final Map<String, dynamic> translationConfiguration;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pipelineVersion': 'context-translation-v1',
    // Order is meaningful: neighboring pages provide directional context.
    'contextPageHashes': contextPageHashes,
    'batchSize': batchSize.pageCount,
    'modelVersion': modelVersion,
    'promptVersion': promptVersion,
    'targetLanguage': targetLanguage,
    'sourceLanguage': sourceLanguage,
    'ocrConfiguration': _canonicalize(ocrConfiguration),
    'translationConfiguration': _canonicalize(translationConfiguration),
  };

  String get canonicalJson => jsonEncode(toJson());

  String get value => sha256.convert(utf8.encode(canonicalJson)).toString();

  String pageKey(String pageId) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode(<String, String>{'batchKey': value, 'pageId': pageId}),
            ),
          )
          .toString();
}

dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final List<String> keys =
        value.keys.map((Object? key) => '$key').toList()..sort();
    return <String, dynamic>{
      for (final String key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

enum ContextTranslationPageStatus { cached, success, failed, canceled }

class ContextTranslationPageOutcome {
  const ContextTranslationPageOutcome({
    required this.pageId,
    required this.persistentKey,
    required this.status,
    this.errorCode,
    this.cachePersisted = false,
  });

  final String pageId;
  final String persistentKey;
  final ContextTranslationPageStatus status;
  final String? errorCode;
  final bool cachePersisted;
}

class ContextTranslationBatchOutcome {
  const ContextTranslationBatchOutcome({
    required this.cacheKey,
    required this.targetPageIds,
    required this.pages,
    required this.engineCalled,
    required this.canceled,
  });

  final ContextTranslationCacheKey cacheKey;
  final List<String> targetPageIds;
  final List<ContextTranslationPageOutcome> pages;
  final bool engineCalled;
  final bool canceled;

  bool get allSucceeded => pages.every(
    (page) =>
        page.status == ContextTranslationPageStatus.success ||
        page.status == ContextTranslationPageStatus.cached,
  );
}

/// Orchestrates one structured context request and fans its ID-addressed
/// output back into the existing per-page image translation cache/overlay.
class ContextTranslationService {
  ContextTranslationService({
    required this.imageTranslationService,
    ContextTranslationEngine? engine,
    ContextTranslationEngine? Function()? engineResolver,
  }) : _engineResolver =
           engineResolver ??
           (() =>
               engine ??
               imageTranslationService
                   .engineRegistry
                   .selectedContextTranslation);

  final ImageTranslationService imageTranslationService;
  final ContextTranslationEngine? Function() _engineResolver;
  ContextTranslationBatch? _lastBatch;

  ContextTranslationBatch? get lastBatch => _lastBatch;

  Future<ContextTranslationBatchOutcome> translateBatch(
    ContextTranslationBatch batch, {
    bool force = false,
    Set<String>? targetPageIds,
    int? batchGeneration,
  }) async {
    _validateBatch(batch);
    final List<String> targets = _targetPageIds(batch, targetPageIds);
    _lastBatch = batch;
    final Map<String, ContextTranslationPage> pagesById = <
      String,
      ContextTranslationPage
    >{for (final ContextTranslationPage page in batch.pages) page.pageId: page};
    final List<ContextTranslationPage> pending = <ContextTranslationPage>[];
    final List<ContextTranslationPageOutcome> outcomes =
        <ContextTranslationPageOutcome>[];
    final bool ownsBatchLifecycle = batchGeneration == null;
    final int generation =
        batchGeneration ?? imageTranslationService.beginBatch(targets.length);
    final ContextTranslationCacheKey cacheKey = batch.cacheKey;
    EngineTask<ContextTranslationResult>? task;
    bool engineCalled = false;
    bool canceled = false;

    try {
      for (final String pageId in targets) {
        final ContextTranslationPage page = pagesById[pageId]!;
        final String persistentKey = cacheKey.pageKey(page.pageId);
        imageTranslationService.queue(page.displayCacheKey);
        final ImageTranslationResult? cached =
            force
                ? null
                : await imageTranslationService.readPersistentResultForKey(
                  persistentKey,
                );
        if (cached != null) {
          imageTranslationService.publishResult(
            page.displayCacheKey,
            cached.copyWith(fromCache: true),
          );
          outcomes.add(
            ContextTranslationPageOutcome(
              pageId: page.pageId,
              persistentKey: persistentKey,
              status: ContextTranslationPageStatus.cached,
              cachePersisted: true,
            ),
          );
          imageTranslationService.recordBatchResult(
            page.displayCacheKey,
            generation: generation,
          );
        } else {
          pending.add(page);
        }
      }

      if (pending.isNotEmpty && imageTranslationService.isCancelRequested) {
        canceled = true;
        _publishPendingTerminal(
          pending,
          outcomes,
          cacheKey,
          generation,
          canceled: true,
        );
      } else if (pending.isNotEmpty) {
        imageTranslationService.setBatchStage(
          ImageTranslationStage.translating,
        );
        final ContextTranslationEngine? engine = _engineResolver();
        if (engine == null || !engine.isReady) {
          _publishPendingTerminal(
            pending,
            outcomes,
            cacheKey,
            generation,
            errorCode: 'CONTEXT_ENGINE_UNAVAILABLE',
          );
        } else {
          engineCalled = true;
          task = engine.translateContext(batch.toEngineRequest(targets));
          imageTranslationService.attachExternalBatchTask(
            task,
            activeCacheKey: pending.first.displayCacheKey,
          );
          final Duration timeout = Duration(
            minutes: batch.batchSize.pageCount >= 4 ? 5 : 2,
          );
          final ContextTranslationResult result = await task.future.timeout(
            timeout,
            onTimeout: () {
              task!.cancel('context translation timeout');
              throw const EngineException(
                code: 'timeout',
                message: 'Context translation timed out.',
                engineId: 'context-translation',
              );
            },
          );
          await _applyEngineResult(
            batch,
            pending,
            result,
            outcomes,
            cacheKey,
            generation,
          );
        }
      }
    } on EngineTaskCancelledException {
      canceled = true;
      _publishPendingTerminal(
        pending,
        outcomes,
        cacheKey,
        generation,
        canceled: true,
      );
    } on EngineException catch (error) {
      _publishPendingTerminal(
        pending,
        outcomes,
        cacheKey,
        generation,
        errorCode: 'CONTEXT_ENGINE_${error.code.toUpperCase()}',
      );
    } on TimeoutException {
      _publishPendingTerminal(
        pending,
        outcomes,
        cacheKey,
        generation,
        errorCode: 'CONTEXT_ENGINE_TIMEOUT',
      );
    } on Object {
      _publishPendingTerminal(
        pending,
        outcomes,
        cacheKey,
        generation,
        errorCode: 'CONTEXT_TRANSLATION_FAILED',
      );
    } finally {
      if (task != null) {
        imageTranslationService.detachExternalBatchTask(task);
      }
      if (ownsBatchLifecycle) {
        imageTranslationService.endBatch(generation);
      }
    }

    return ContextTranslationBatchOutcome(
      cacheKey: cacheKey,
      targetPageIds: List<String>.unmodifiable(targets),
      pages: List<ContextTranslationPageOutcome>.unmodifiable(outcomes),
      engineCalled: engineCalled,
      canceled: canceled,
    );
  }

  Future<ContextTranslationBatchOutcome?> retryPage(String pageId) {
    final ContextTranslationBatch? batch = _lastBatch;
    if (batch == null || !batch.pages.any((page) => page.pageId == pageId)) {
      return Future<ContextTranslationBatchOutcome?>.value(null);
    }
    return translateBatch(batch, force: true, targetPageIds: <String>{pageId});
  }

  Future<ContextTranslationBatchOutcome?> retryBatch() {
    final ContextTranslationBatch? batch = _lastBatch;
    if (batch == null) {
      return Future<ContextTranslationBatchOutcome?>.value(null);
    }
    return translateBatch(batch, force: true);
  }

  void cancel() => imageTranslationService.cancelBatch();

  Future<bool> hydratePage(ContextTranslationBatch batch, String pageId) async {
    _validateBatch(batch);
    final ContextTranslationPage page = batch.pages.firstWhere(
      (candidate) => candidate.pageId == pageId,
    );
    return imageTranslationService.hydratePersistentResult(
      displayCacheKey: page.displayCacheKey,
      persistentKey: batch.cacheKey.pageKey(page.pageId),
    );
  }

  Future<void> _applyEngineResult(
    ContextTranslationBatch batch,
    List<ContextTranslationPage> pending,
    ContextTranslationResult result,
    List<ContextTranslationPageOutcome> outcomes,
    ContextTranslationCacheKey cacheKey,
    int generation,
  ) async {
    final Map<String, Map<String, ContextTranslationLineResult>> byPage =
        <String, Map<String, ContextTranslationLineResult>>{};
    final Set<String> invalidPages = <String>{};
    final Set<String> expectedPages =
        batch.pages.map((page) => page.pageId).toSet();
    for (final ContextTranslationLineResult line in result.lines) {
      if (!expectedPages.contains(line.pageId)) {
        for (final ContextTranslationPage page in pending) {
          invalidPages.add(page.pageId);
        }
        continue;
      }
      final Map<String, ContextTranslationLineResult> lines = byPage
          .putIfAbsent(
            line.pageId,
            () => <String, ContextTranslationLineResult>{},
          );
      if (lines.containsKey(line.lineId)) {
        invalidPages.add(line.pageId);
      } else {
        lines[line.lineId] = line;
      }
    }

    for (final ContextTranslationPage page in pending) {
      final String persistentKey = cacheKey.pageKey(page.pageId);
      final Map<String, ContextTranslationLineResult> lines =
          byPage[page.pageId] ?? <String, ContextTranslationLineResult>{};
      String? errorCode;
      final List<String> translated = <String>[];
      if (invalidPages.contains(page.pageId)) {
        errorCode = 'CONTEXT_INVALID_RESPONSE';
      } else {
        for (final ContextTranslationPageLine sourceLine in page.lines) {
          final ContextTranslationLineResult? line = lines[sourceLine.lineId];
          if (line == null) {
            errorCode = 'CONTEXT_MISSING_LINE';
            break;
          }
          if (line.errorCode != null) {
            errorCode = line.errorCode;
            break;
          }
          final String text = line.translatedText.trim();
          if (text.isEmpty) {
            errorCode = 'CONTEXT_EMPTY_LINE';
            break;
          }
          translated.add(text);
        }
      }
      if (errorCode != null) {
        _publishPageFailure(
          page,
          outcomes,
          persistentKey,
          errorCode,
          generation,
        );
        continue;
      }
      final ImageTranslationResult imageResult = ImageTranslationResult(
        status: ImageTranslationStatus.success,
        sourceText: page.sourceText,
        translatedText: translated.join('\n'),
        blocks: page.blocks,
        imageWidth: page.imageWidth,
        imageHeight: page.imageHeight,
      );
      imageTranslationService.publishResult(page.displayCacheKey, imageResult);
      bool cachePersisted = false;
      try {
        await imageTranslationService.writePersistentResultForKey(
          persistentKey,
          imageResult,
        );
        cachePersisted = true;
      } on Object {
        // The visible result remains usable, but the outcome records that the
        // required per-page durable write did not complete.
      }
      outcomes.add(
        ContextTranslationPageOutcome(
          pageId: page.pageId,
          persistentKey: persistentKey,
          status: ContextTranslationPageStatus.success,
          errorCode: cachePersisted ? null : 'CONTEXT_CACHE_WRITE_FAILED',
          cachePersisted: cachePersisted,
        ),
      );
      imageTranslationService.recordBatchResult(
        page.displayCacheKey,
        generation: generation,
      );
    }
  }

  void _publishPendingTerminal(
    List<ContextTranslationPage> pages,
    List<ContextTranslationPageOutcome> outcomes,
    ContextTranslationCacheKey cacheKey,
    int generation, {
    String? errorCode,
    bool canceled = false,
  }) {
    for (final ContextTranslationPage page in pages) {
      final String persistentKey = cacheKey.pageKey(page.pageId);
      if (outcomes.any((outcome) => outcome.pageId == page.pageId)) {
        continue;
      }
      _publishPageFailure(
        page,
        outcomes,
        persistentKey,
        canceled ? 'CANCELED' : (errorCode ?? 'CONTEXT_TRANSLATION_FAILED'),
        generation,
        canceled: canceled,
      );
    }
  }

  void _publishPageFailure(
    ContextTranslationPage page,
    List<ContextTranslationPageOutcome> outcomes,
    String persistentKey,
    String errorCode,
    int generation, {
    bool canceled = false,
  }) {
    imageTranslationService.publishResult(
      page.displayCacheKey,
      ImageTranslationResult(
        status:
            canceled
                ? ImageTranslationStatus.canceled
                : ImageTranslationStatus.failed,
        sourceText: page.sourceText,
        blocks: page.blocks,
        imageWidth: page.imageWidth,
        imageHeight: page.imageHeight,
        errorMessage: errorCode,
      ),
    );
    outcomes.add(
      ContextTranslationPageOutcome(
        pageId: page.pageId,
        persistentKey: persistentKey,
        status:
            canceled
                ? ContextTranslationPageStatus.canceled
                : ContextTranslationPageStatus.failed,
        errorCode: errorCode,
      ),
    );
    imageTranslationService.recordBatchResult(
      page.displayCacheKey,
      generation: generation,
    );
  }

  List<String> _targetPageIds(
    ContextTranslationBatch batch,
    Set<String>? requested,
  ) {
    final List<String> all = batch.pages.map((page) => page.pageId).toList();
    if (requested == null) {
      return all;
    }
    final Set<String> known = all.toSet();
    if (requested.isEmpty || requested.any((id) => !known.contains(id))) {
      throw ArgumentError.value(requested, 'targetPageIds');
    }
    return all.where(requested.contains).toList(growable: false);
  }

  void _validateBatch(ContextTranslationBatch batch) {
    if (batch.pages.isEmpty || batch.pages.length > batch.batchSize.pageCount) {
      throw ArgumentError.value(batch.pages.length, 'pages');
    }
    if (batch.modelVersion.trim().isEmpty ||
        batch.targetLanguage.trim().isEmpty) {
      throw ArgumentError('modelVersion and targetLanguage are required.');
    }
    final Set<String> pageIds = <String>{};
    final Set<String> displayKeys = <String>{};
    for (final ContextTranslationPage page in batch.pages) {
      if (page.pageId.trim().isEmpty || !pageIds.add(page.pageId)) {
        throw ArgumentError.value(page.pageId, 'pageId');
      }
      if (!displayKeys.add(page.displayCacheKey)) {
        throw ArgumentError.value(page.displayCacheKey, 'displayCacheKey');
      }
      if (page.pageHash.trim().isEmpty || page.lines.isEmpty) {
        throw ArgumentError.value(page.pageId, 'page');
      }
      final Set<String> lineIds = <String>{};
      for (final ContextTranslationPageLine line in page.lines) {
        if (line.lineId.trim().isEmpty || !lineIds.add(line.lineId)) {
          throw ArgumentError.value(line.lineId, 'lineId');
        }
      }
    }
  }
}
