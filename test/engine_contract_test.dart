import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/engine/engine.dart';

class _FakeOcrEngine implements OcrEngine {
  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'fake-ocr',
    kind: EngineKind.ocr,
    displayName: 'Fake OCR',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<OcrResult> recognize(OcrEngineRequest request) => EngineTask.start(
    operation: (EngineTaskContext context) async {
      context.report(EngineTaskStage.processing, 0.5);
      return const OcrResult(blocks: <RecognizedTextBlock>[]);
    },
  );
}

class _FakeTranslationEngine implements TranslationEngine {
  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'fake-translation',
    kind: EngineKind.translation,
    displayName: 'Fake Translation',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<TranslationResult> translate(TranslationEngineRequest request) =>
      EngineTask.start(
        operation:
            (EngineTaskContext context) async => const TranslationResult(
              translatedText: 'translated',
              lines: <String>['translated'],
            ),
      );
}

void main() {
  test('engine task has one id across lifecycle and progress events', () async {
    final EngineTask<int> task = EngineTask.start(
      id: 'task-contract-test',
      operation: (EngineTaskContext context) async {
        context.report(EngineTaskStage.processing, 0.4, message: 'working');
        return 7;
      },
    );
    final List<EngineTaskProgress> events = await task.progress.toList();
    expect(await task.future, 7);
    expect(task.lifecycle, EngineTaskLifecycle.succeeded);
    expect(events, isNotEmpty);
    expect(
      events.map((EngineTaskProgress event) => event.taskId).toSet(),
      <String>{'task-contract-test'},
    );
    expect(events.last.stage, EngineTaskStage.completed);
    expect(events.last.fraction, 1);
  });

  test('engine task cancellation is mapped consistently', () async {
    final Completer<void> gate = Completer<void>();
    final EngineTask<void> task = EngineTask.start(
      operation: (EngineTaskContext context) async {
        await gate.future;
        context.cancellation.throwIfCancelled();
      },
    );
    task.cancel('user stopped');
    gate.complete();
    await expectLater(
      task.future,
      throwsA(isA<EngineTaskCancelledException>()),
    );
    expect(task.lifecycle, EngineTaskLifecycle.cancelled);
    expect(task.error?.code, 'cancelled');
  });

  test('cache key changes with model, configuration, prompt and pipeline', () {
    EngineCacheKey key({
      String model = 'model-a',
      Map<String, dynamic> configuration = const <String, dynamic>{
        'target': 'zh',
      },
      int prompt = 1,
      String pipeline = 'v1',
    }) => EngineCacheKey(
      sourceHash: 'image-hash',
      ocrModel: 'ocr-a',
      ocrConfiguration: const <String, dynamic>{'language': 'ja'},
      translationModel: model,
      translationConfiguration: configuration,
      promptVersion: prompt,
      pipelineVersion: pipeline,
    );

    expect(key().value, key().value);
    expect(key().value, isNot(key(model: 'model-b').value));
    expect(
      key().value,
      isNot(key(configuration: const <String, dynamic>{'target': 'en'}).value),
    );
    expect(key().value, isNot(key(prompt: 2).value));
    expect(key().value, isNot(key(pipeline: 'v2').value));
    expect(
      key(configuration: const <String, dynamic>{'b': 2, 'a': 1}).value,
      key(configuration: const <String, dynamic>{'a': 1, 'b': 2}).value,
    );
  });

  test(
    'capability matrix composes independent OCR and translation adapters',
    () {
      final EngineCapabilityMatrix matrix = const EngineCapabilityMatrix();
      final EngineCapabilityDecision decision = matrix.evaluate(
        ocr: _FakeOcrEngine(),
        translation: _FakeTranslationEngine(),
        platform: EnginePlatform.macos,
      );
      expect(decision.supported, isTrue);
      final EngineCapabilityDecision unsupported = matrix.evaluate(
        ocr: _FakeOcrEngine(),
        translation: _FakeTranslationEngine(),
        platform: EnginePlatform.android,
      );
      expect(unsupported.supported, isFalse);
    },
  );

  test('ONNX model catalog exposes only verified manifest artifacts', () {
    final OnnxModelCatalog catalog = OnnxModelCatalog();
    final ModelDescriptor ocr =
        catalog.find('rapidocr-ppocrv6-small-multilingual')!;
    expect(ocr.engineIds, contains('onnx-ocr'));
    expect(ocr.artifacts, isNotEmpty);
    expect(
      ocr.artifacts.every(
        (ModelArtifactDescriptor artifact) =>
            artifact.sha256.length == 64 && artifact.sizeBytes > 0,
      ),
      isTrue,
    );
    final Map<String, dynamic> json = ocr.toJson();
    expect(json['schemaVersion'], modelCatalogSchemaVersion);
    expect(ModelDescriptor.fromJson(json).fingerprint, ocr.fingerprint);
  });
}
