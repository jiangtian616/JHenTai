import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/context_translation_service.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/image_translation_service.dart';

class _FakeContextEngine implements ContextTranslationEngine {
  _FakeContextEngine({this.omitPageId, this.waitForCancellation = false});

  String? omitPageId;
  final bool waitForCancellation;
  int calls = 0;
  final List<ContextTranslationEngineRequest> requests =
      <ContextTranslationEngineRequest>[];

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'fake-context-translation',
    kind: EngineKind.translation,
    displayName: 'Fake context translation',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<ContextTranslationResult> translateContext(
    ContextTranslationEngineRequest request,
  ) {
    calls++;
    requests.add(request);
    return EngineTask.start(
      operation: (EngineTaskContext context) async {
        if (waitForCancellation) {
          final Completer<void> gate = Completer<void>();
          final StreamSubscription<String> subscription = context
              .cancellation
              .onCancel
              .listen((_) {
                if (!gate.isCompleted) gate.complete();
              });
          try {
            await gate.future;
            context.cancellation.throwIfCancelled();
          } finally {
            await subscription.cancel();
          }
        }
        context.report(EngineTaskStage.processing, 0.5);
        final List<ContextTranslationLineResult> lines =
            <ContextTranslationLineResult>[];
        for (final ContextTranslationPageRequest page in request.pages) {
          if (page.pageId == omitPageId) continue;
          for (final ContextTranslationLineRequest line
              in page.lines.reversed) {
            lines.add(
              ContextTranslationLineResult(
                pageId: page.pageId,
                lineId: line.lineId,
                translatedText: 'translated:${page.pageId}:${line.lineId}',
              ),
            );
          }
        }
        return ContextTranslationResult(lines: lines.reversed.toList());
      },
    );
  }
}

ContextTranslationPage _page(String id) {
  final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
    RecognizedTextBlock(
      text: '$id source 1',
      confidence: 0.99,
      left: 10,
      top: 20,
      width: 100,
      height: 30,
    ),
    RecognizedTextBlock(
      text: '$id source 2',
      confidence: 0.98,
      left: 10,
      top: 60,
      width: 100,
      height: 30,
    ),
  ];
  return ContextTranslationPage.fromBlocks(
    pageId: id,
    displayCacheKey: 'display-$id',
    sourceHash: 'source-hash-$id',
    blocks: blocks,
    sourceText: blocks.map((block) => block.text).join('\n'),
    imageWidth: 800,
    imageHeight: 1200,
  );
}

ContextTranslationBatch _batch(ContextBatchSize size, {int? pageCount}) {
  final int count = pageCount ?? size.pageCount;
  return ContextTranslationBatch(
    pages: List<ContextTranslationPage>.generate(
      count,
      (int index) => _page('page-${index + 1}'),
    ),
    batchSize: size,
    modelVersion: 'model-v1',
    promptVersion: 7,
    targetLanguage: '简体中文',
    sourceLanguage: '日语',
    ocrConfiguration: const <String, dynamic>{
      'engine': 'onnx',
      'language': 'jpn',
    },
  );
}

void main() {
  test('only the fixed 1/2/4/8 batch sizes are partitioned', () {
    final List<int> values =
        ContextBatchSize.values
            .map((ContextBatchSize size) => size.pageCount)
            .toList();
    expect(values, <int>[1, 2, 4, 8]);
    final List<String> pages = List<String>.generate(
      9,
      (int index) => '$index',
    );
    expect(
      ContextTranslationBatch.partition(pages, ContextBatchSize.one),
      hasLength(9),
    );
    expect(
      ContextTranslationBatch.partition(pages, ContextBatchSize.two),
      hasLength(5),
    );
    expect(
      ContextTranslationBatch.partition(pages, ContextBatchSize.four),
      hasLength(3),
    );
    expect(
      ContextTranslationBatch.partition(pages, ContextBatchSize.eight),
      hasLength(2),
    );
  });

  test(
    'context cache key includes ordered hashes, strategy, model, prompt and OCR config',
    () {
      final ContextTranslationBatch batch = _batch(
        ContextBatchSize.two,
        pageCount: 2,
      );
      final ContextTranslationCacheKey key = batch.cacheKey;
      expect(key.value, key.value);
      expect(
        key.value,
        isNot(
          ContextTranslationCacheKey(
            contextPageHashes: key.contextPageHashes.reversed.toList(),
            batchSize: key.batchSize,
            modelVersion: key.modelVersion,
            promptVersion: key.promptVersion,
            targetLanguage: key.targetLanguage,
            sourceLanguage: key.sourceLanguage,
            ocrConfiguration: key.ocrConfiguration,
          ).value,
        ),
      );
      expect(
        key.value,
        isNot(
          ContextTranslationCacheKey(
            contextPageHashes: key.contextPageHashes,
            batchSize: ContextBatchSize.four,
            modelVersion: key.modelVersion,
            promptVersion: key.promptVersion,
            targetLanguage: key.targetLanguage,
            sourceLanguage: key.sourceLanguage,
            ocrConfiguration: key.ocrConfiguration,
          ).value,
        ),
      );
      expect(
        key.value,
        isNot(
          ContextTranslationCacheKey(
            contextPageHashes: key.contextPageHashes,
            batchSize: key.batchSize,
            modelVersion: 'model-v2',
            promptVersion: key.promptVersion + 1,
            targetLanguage: key.targetLanguage,
            sourceLanguage: key.sourceLanguage,
            ocrConfiguration: const <String, dynamic>{'language': 'eng'},
          ).value,
        ),
      );
    },
  );

  test(
    'one structured request maps reversed lines to pages and persists each page',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'context-translation-cache',
      );
      final ImageTranslationService imageService = ImageTranslationService();
      imageService.setTranslationCacheDirectoryForTesting(temp);
      final _FakeContextEngine engine = _FakeContextEngine();
      final ContextTranslationService service = ContextTranslationService(
        imageTranslationService: imageService,
        engine: engine,
      );
      final ContextTranslationBatch batch = _batch(
        ContextBatchSize.two,
        pageCount: 2,
      );

      try {
        final ContextTranslationBatchOutcome first = await service
            .translateBatch(batch);
        expect(first.allSucceeded, isTrue);
        expect(first.engineCalled, isTrue);
        expect(engine.calls, 1);
        expect(engine.requests.single.pages, hasLength(2));
        expect(engine.requests.single.pages.first.lines.first.pageId, 'page-1');

        for (final ContextTranslationPage page in batch.pages) {
          final ImageTranslationResult result = imageService.resultFor(
            page.displayCacheKey,
          );
          expect(result.status, ImageTranslationStatus.success);
          expect(result.translatedText, contains('translated:${page.pageId}'));
          expect(
            await File(
              '${temp.path}/${batch.cacheKey.pageKey(page.pageId)}.json',
            ).exists(),
            isTrue,
          );
        }

        final ContextTranslationBatchOutcome cached = await service
            .translateBatch(batch);
        expect(cached.allSucceeded, isTrue);
        expect(
          cached.pages.every(
            (page) => page.status == ContextTranslationPageStatus.cached,
          ),
          isTrue,
        );
        expect(engine.calls, 1);

        imageService.removeResult(batch.pages.first.displayCacheKey);
        expect(await service.hydratePage(batch, 'page-1'), isTrue);
        expect(
          imageService.resultFor(batch.pages.first.displayCacheKey).fromCache,
          isTrue,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test('one page can fail and retry without discarding another page', () async {
    final Directory temp = await Directory.systemTemp.createTemp(
      'context-translation-retry',
    );
    final ImageTranslationService imageService = ImageTranslationService();
    imageService.setTranslationCacheDirectoryForTesting(temp);
    final _FakeContextEngine engine = _FakeContextEngine(omitPageId: 'page-2');
    final ContextTranslationService service = ContextTranslationService(
      imageTranslationService: imageService,
      engine: engine,
    );
    final ContextTranslationBatch batch = _batch(
      ContextBatchSize.two,
      pageCount: 2,
    );

    try {
      final ContextTranslationBatchOutcome partial = await service
          .translateBatch(batch);
      expect(
        partial.pages.map((page) => page.status),
        <ContextTranslationPageStatus>[
          ContextTranslationPageStatus.success,
          ContextTranslationPageStatus.failed,
        ],
      );
      expect(
        imageService.resultFor('display-page-1').status,
        ImageTranslationStatus.success,
      );
      expect(
        imageService.resultFor('display-page-2').status,
        ImageTranslationStatus.failed,
      );
      expect(
        await File(
          '${temp.path}/${batch.cacheKey.pageKey('page-1')}.json',
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          '${temp.path}/${batch.cacheKey.pageKey('page-2')}.json',
        ).exists(),
        isFalse,
      );

      engine.omitPageId = null;
      final ContextTranslationBatchOutcome? pageRetry = await service.retryPage(
        'page-2',
      );
      expect(pageRetry, isNotNull);
      expect(pageRetry!.targetPageIds, <String>['page-2']);
      expect(pageRetry.allSucceeded, isTrue);
      expect(
        imageService.resultFor('display-page-1').status,
        ImageTranslationStatus.success,
      );
      expect(
        imageService.resultFor('display-page-2').status,
        ImageTranslationStatus.success,
      );
      expect(engine.requests.last.targetPageIds, <String>['page-2']);

      final ContextTranslationBatchOutcome? fullRetry =
          await service.retryBatch();
      expect(fullRetry, isNotNull);
      expect(fullRetry!.targetPageIds, <String>['page-1', 'page-2']);
      expect(fullRetry.allSucceeded, isTrue);
      expect(engine.calls, 3);
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('all four batch sizes cancel through the existing batch task', () async {
    for (final ContextBatchSize size in ContextBatchSize.values) {
      final Directory temp = await Directory.systemTemp.createTemp(
        'context-translation-cancel',
      );
      final ImageTranslationService imageService = ImageTranslationService();
      imageService.setTranslationCacheDirectoryForTesting(temp);
      final _FakeContextEngine engine = _FakeContextEngine(
        waitForCancellation: true,
      );
      final ContextTranslationService service = ContextTranslationService(
        imageTranslationService: imageService,
        engine: engine,
      );
      final Future<ContextTranslationBatchOutcome> future = service
          .translateBatch(_batch(size));
      await Future<void>.delayed(Duration.zero);
      service.cancel();
      final ContextTranslationBatchOutcome outcome = await future;
      expect(outcome.canceled, isTrue);
      expect(outcome.pages, hasLength(size.pageCount));
      expect(
        outcome.pages.every(
          (page) => page.status == ContextTranslationPageStatus.canceled,
        ),
        isTrue,
      );
      await temp.delete(recursive: true);
    }
  });
}
