import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/context_translation_service.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/image_translation_service.dart';

/// A fake engine that behaves like a *cooperative* model: it echoes the exact
/// pageId/lineId pairs from the request. This mirrors what the existing service
/// tests assume.
class CooperativeContextEngine implements ContextTranslationEngine {
  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'cooperative-context',
    kind: EngineKind.translation,
    displayName: 'Cooperative context engine',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<ContextTranslationResult> translateContext(
    ContextTranslationEngineRequest request,
  ) {
    return EngineTask.start(
      operation: (EngineTaskContext context) async {
        final List<ContextTranslationLineResult> lines =
            <ContextTranslationLineResult>[];
        for (final ContextTranslationPageRequest page in request.pages) {
          for (final ContextTranslationLineRequest line in page.lines) {
            lines.add(
              ContextTranslationLineResult(
                pageId: page.pageId,
                lineId: line.lineId,
                translatedText: 'translated:${line.sourceText}',
              ),
            );
          }
        }
        return ContextTranslationResult(lines: lines);
      },
    );
  }
}

/// A fake engine that behaves like a *realistic* small model: it cannot follow
/// the structured-ID JSON contract (the failure mode when a model has been
/// prompted for the numbered-lines format and ignores the context instruction).
class NumberedLinesContextEngine implements ContextTranslationEngine {
  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'numbered-lines-context',
    kind: EngineKind.translation,
    displayName: 'Numbered lines context engine',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<ContextTranslationResult> translateContext(
    ContextTranslationEngineRequest request,
  ) {
    return EngineTask.start(
      operation: (EngineTaskContext context) async {
        throw const FormatException(
          'model returned numbered lines, not a translations[] JSON',
        );
      },
    );
  }
}

ContextTranslationPage _page(String id, int lines) {
  final List<RecognizedTextBlock> blocks = List<RecognizedTextBlock>.generate(
    lines,
    (int i) => RecognizedTextBlock(
      text: '$id source $i',
      confidence: 0.99,
      left: 10.0 * i,
      top: 20.0,
      width: 100,
      height: 30,
    ),
  );
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

/// Mirrors the reader's `_translatePagesWithContext` partition + per-batch
/// translateBatch loop for `order = [0..2]` and a 2-page batch size.
Future<ContextTranslationBatchOutcome?> runReaderFlow({
  required ContextTranslationService service,
  required ContextBatchSize size,
}) async {
  final List<int> order = <int>[0, 1, 2];
  final int generation = service.imageTranslationService.beginBatch(
    order.length,
  );
  final List<List<int>> batches = ContextTranslationBatch.partition(
    order,
    size,
  );
  ContextTranslationBatchOutcome? last;
  for (final List<int> indices in batches) {
    final List<ContextTranslationPage> pages = <ContextTranslationPage>[
      for (final int index in indices) _page('page-$index', 3),
    ];
    if (pages.isEmpty) {
      continue;
    }
    last = await service.translateBatch(
      ContextTranslationBatch(
        pages: pages,
        batchSize: size,
        modelVersion: 'test-model',
        promptVersion: 1,
        targetLanguage: '简体中文',
        sourceLanguage: '日语',
        ocrConfiguration: const <String, dynamic>{'engine': 'onnx'},
      ),
      batchGeneration: generation,
    );
  }
  service.imageTranslationService.endBatch(generation);
  return last;
}

void main() {
  test(
    'reader multi-batch context flow succeeds when the engine echoes exact IDs',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'reader-context-flow',
      );
      final ImageTranslationService imageService = ImageTranslationService();
      imageService.setTranslationCacheDirectoryForTesting(temp);
      final ContextTranslationService service = ContextTranslationService(
        imageTranslationService: imageService,
        engine: CooperativeContextEngine(),
      );

      try {
        final ContextTranslationBatchOutcome? outcome = await runReaderFlow(
          service: service,
          size: ContextBatchSize.two,
        );
        expect(outcome, isNotNull);
        expect(outcome!.allSucceeded, isTrue);
        expect(
          imageService.resultFor('display-page-0').status,
          ImageTranslationStatus.success,
        );
        expect(
          imageService.resultFor('display-page-1').status,
          ImageTranslationStatus.success,
        );
        expect(
          imageService.resultFor('display-page-2').status,
          ImageTranslationStatus.success,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'a context batch that cannot follow the JSON contract fails every page',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'reader-context-flow-fail',
      );
      final ImageTranslationService imageService = ImageTranslationService();
      imageService.setTranslationCacheDirectoryForTesting(temp);
      final ContextTranslationService service = ContextTranslationService(
        imageTranslationService: imageService,
        engine: NumberedLinesContextEngine(),
      );

      try {
        final ContextTranslationBatchOutcome? outcome = await runReaderFlow(
          service: service,
          size: ContextBatchSize.two,
        );
        expect(outcome, isNotNull);
        expect(outcome!.allSucceeded, isFalse);
        for (final ContextTranslationPageOutcome page in outcome.pages) {
          expect(page.status, ContextTranslationPageStatus.failed);
        }
        expect(
          imageService.resultFor('display-page-0').status,
          ImageTranslationStatus.failed,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}
