import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/engine.dart';
import 'package:jhentai/src/service/image_inpainting_service.dart';
import 'package:jhentai/src/service/inference/ctd_model_evidence.dart';
import 'package:jhentai/src/service/inference/ctd_onnx_inference_engine.dart';
import 'package:jhentai/src/service/inference/migan_model_evidence.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';

class _FakeInpaintEngine implements InpaintEngine {
  _FakeInpaintEngine({this.failure});

  final String? failure;
  int calls = 0;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'onnx-migan-inpaint',
    kind: EngineKind.inpaint,
    displayName: 'fake inpaint',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<String> inpaint(ImageProcessingRequest request) =>
      EngineTask<String>.start(
        operation: (EngineTaskContext context) async {
          calls++;
          if (failure != null) {
            throw EngineException(
              code: failure!,
              message: 'fake failure',
              engineId: descriptor.id,
            );
          }
          context.cancellation.throwIfCancelled();
          await request.outputPathFile.parent.create(recursive: true);
          await request.outputPathFile.writeAsBytes(<int>[
            1,
            2,
            3,
          ], flush: true);
          return request.outputPath;
        },
      );
}

class _FakeDetectionEngine implements DetectionEngine {
  _FakeDetectionEngine({this.masks = const <PolygonMask>[]});

  final List<PolygonMask> masks;
  int calls = 0;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'ctd-detection',
    kind: EngineKind.detection,
    displayName: 'fake CTD',
    platforms: <EnginePlatform>{EnginePlatform.macos},
  );

  @override
  bool get isReady => true;

  @override
  EngineTask<DetectionResult> detect(EngineImageRequest request) =>
      EngineTask<DetectionResult>.start(
        operation: (EngineTaskContext context) async {
          calls++;
          context.cancellation.throwIfCancelled();
          return DetectionResult(regions: const [], polygonMasks: masks);
        },
      );
}

extension on ImageProcessingRequest {
  File get outputPathFile => File(outputPath);
}

PolygonMask _squareMask() => const PolygonMask(
  points: <EnginePoint>[
    EnginePoint(x: 1, y: 1),
    EnginePoint(x: 5, y: 1),
    EnginePoint(x: 5, y: 5),
    EnginePoint(x: 1, y: 5),
  ],
  confidence: 0.95,
);

void main() {
  test(
    'CTD adapter preserves polygon masks and projects compatibility boxes',
    () async {
      final CtdDetectionEngineAdapter adapter = CtdDetectionEngineAdapter(
        runner: (
          String path,
          EngineCancellationToken token,
          void Function(double) onProgress,
        ) async {
          token.throwIfCancelled();
          onProgress(1);
          return CtdDetectionOutput(polygonMasks: <PolygonMask>[_squareMask()]);
        },
      );

      final DetectionResult result =
          await adapter
              .detect(const EngineImageRequest(imagePath: 'page.png'))
              .future;

      expect(adapter.isReady, isTrue);
      expect(result.polygonMasks.single.points, hasLength(4));
      expect(result.regions.single.left, 1);
      expect(result.regions.single.top, 1);
      expect(result.regions.single.width, 4);
      expect(result.regions.single.height, 4);
    },
  );

  test(
    'an adapter without a CTD runtime remains explicitly unavailable',
    () async {
      final CtdDetectionEngineAdapter adapter = CtdDetectionEngineAdapter();
      expect(adapter.isReady, isFalse);
      await expectLater(
        adapter.detect(const EngineImageRequest(imagePath: 'page.png')).future,
        throwsA(
          isA<EngineException>().having(
            (EngineException error) => error.code,
            'code',
            'model_unavailable',
          ),
        ),
      );
      expect(CtdModelEvidence.modelArtifactPinned, isTrue);
      expect(CtdModelEvidence.nativeRuntimeVerified, isTrue);
    },
  );

  test('CTD segmentation becomes source-coordinate polygons, not boxes', () {
    final Float32List probabilities = Float32List(8 * 8);
    for (int y = 2; y <= 4; y++) {
      for (int x = 1; x <= 3; x++) {
        probabilities[y * 8 + x] = 0.9;
      }
    }
    // This active pixel is in the padded area and must be ignored.
    probabilities[7 * 8 + 7] = 1;

    final List<PolygonMask> masks = ctdPolygonsFromSegmentation(
      probabilities: probabilities,
      mapWidth: 8,
      mapHeight: 8,
      activeWidth: 6,
      activeHeight: 6,
      sourceWidth: 60,
      sourceHeight: 120,
      dilationRadius: 0,
      minimumPixels: 4,
    );

    expect(masks, hasLength(1));
    expect(masks.single.isValid, isTrue);
    expect(masks.single.points.length, greaterThanOrEqualTo(4));
    expect(masks.single.left, closeTo(10, 0.01));
    expect(masks.single.top, closeTo(40, 0.01));
    expect(masks.single.right, closeTo(30, 0.01));
    expect(masks.single.bottom, closeTo(80, 0.01));
  });

  test(
    'inpainting cache is independent and keeps the source hash unchanged',
    () async {
      final Directory root = await Directory.systemTemp.createTemp(
        'jhentai-ctd-inpainting-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final File source = File('${root.path}/source.bin');
      await source.writeAsBytes(<int>[7, 8, 9, 10], flush: true);
      final Directory cache = Directory('${root.path}/cache');
      final _FakeInpaintEngine fake = _FakeInpaintEngine();
      final EngineRegistry registry = EngineRegistry(inpaintEngine: fake);
      final ImageInpaintingService service = ImageInpaintingService(
        registry: registry,
      )..setCacheDirectoryForTesting(cache);

      final String originalHash = await source.sha256ForTest();
      final InpaintingResult first = await service.repair(
        requestKey: 'page-1',
        sourcePath: source.path,
        polygonMasks: <PolygonMask>[_squareMask()],
      );
      expect(first.status, InpaintingStatus.success);
      expect(first.outputPath, isNot(source.path));
      expect(await source.sha256ForTest(), originalHash);
      expect(await File(first.outputPath!).exists(), isTrue);

      final ImageInpaintingService restarted = ImageInpaintingService(
        registry: registry,
      )..setCacheDirectoryForTesting(cache);
      final InpaintingResult cached = await restarted.repair(
        requestKey: 'page-1',
        sourcePath: source.path,
        polygonMasks: <PolygonMask>[_squareMask()],
      );
      expect(cached.status, InpaintingStatus.success);
      expect(cached.fromCache, isTrue);
      expect(fake.calls, 1);

      restarted.setDisplayMode(
        ImageProcessingDisplayMode.repairedBackgroundEmbeddedText,
      );
      expect(restarted.displayPathFor('page-1'), cached.outputPath);
      restarted.setDisplayMode(ImageProcessingDisplayMode.translatedImage);
      expect(restarted.shouldDrawTranslationOverlay('page-1'), isTrue);
      final File translated = File('${root.path}/translated.png')
        ..writeAsBytesSync(<int>[4, 5, 6]);
      restarted.publishTranslatedImage('page-1', translated.path);
      expect(restarted.displayPathFor('page-1'), translated.path);
      expect(restarted.shouldDrawTranslationOverlay('page-1'), isFalse);

      await restarted.clearCache(requestKey: 'page-1');
      expect(await File(cached.outputPath!).exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await source.sha256ForTest(), originalHash);
    },
  );

  test('production pipeline passes CTD polygons to MI-GAN', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-ctd-migan-pipeline-',
    );
    addTearDown(() => root.delete(recursive: true));
    final File source = File('${root.path}/source.bin')
      ..writeAsBytesSync(<int>[9, 8, 7]);
    final _FakeDetectionEngine detector = _FakeDetectionEngine(
      masks: <PolygonMask>[_squareMask()],
    );
    final _FakeInpaintEngine inpainter = _FakeInpaintEngine();
    final ImageInpaintingService service = ImageInpaintingService(
      registry: EngineRegistry(
        detectionEngine: detector,
        inpaintEngine: inpainter,
      ),
    )..setCacheDirectoryForTesting(Directory('${root.path}/cache'));

    final InpaintingResult result = await service.detectAndRepair(
      requestKey: 'page-1',
      sourcePath: source.path,
    );

    expect(result.status, InpaintingStatus.success);
    expect(detector.calls, 1);
    expect(inpainter.calls, 1);
    expect(result.outputPath, isNot(source.path));
    expect(await source.readAsBytes(), <int>[9, 8, 7]);
  });

  test('CTD with no text falls back without invoking MI-GAN', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-ctd-no-text-',
    );
    addTearDown(() => root.delete(recursive: true));
    final File source = File('${root.path}/source.bin')
      ..writeAsBytesSync(<int>[1]);
    final _FakeInpaintEngine inpainter = _FakeInpaintEngine();
    final ImageInpaintingService service = ImageInpaintingService(
      registry: EngineRegistry(
        detectionEngine: _FakeDetectionEngine(),
        inpaintEngine: inpainter,
      ),
    );

    final InpaintingResult result = await service.detectAndRepair(
      requestKey: 'page-1',
      sourcePath: source.path,
    );

    expect(result.status, InpaintingStatus.failed);
    expect(result.errorCode, 'ctd_no_text');
    expect(result.fallbackToOverlay, isTrue);
    expect(inpainter.calls, 0);
  });

  test('inpainting failure explicitly falls back to overlay', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-ctd-inpainting-failure-',
    );
    addTearDown(() => root.delete(recursive: true));
    final File source = File('${root.path}/source.bin')
      ..writeAsBytesSync(<int>[1, 2, 3]);
    final ImageInpaintingService service = ImageInpaintingService(
      registry: EngineRegistry(
        inpaintEngine: _FakeInpaintEngine(failure: 'native_failed'),
      ),
    )..setCacheDirectoryForTesting(Directory('${root.path}/cache'));

    final InpaintingResult result = await service.repair(
      requestKey: 'page-1',
      sourcePath: source.path,
      polygonMasks: <PolygonMask>[_squareMask()],
    );
    expect(result.status, InpaintingStatus.failed);
    expect(result.errorCode, 'native_failed');
    expect(result.fallbackToOverlay, isTrue);
    expect(await source.readAsBytes(), <int>[1, 2, 3]);
  });

  test('ModelScope MI-GAN manifest is pinned to the inspected artifact', () {
    final ModelDescriptor descriptor =
        OnnxModelCatalog().find(OnnxModelStore.miganInpaintManifestId)!;
    final ModelArtifactDescriptor artifact = descriptor.artifacts.single;
    expect(artifact.sizeBytes, MiganModelEvidence.artifactSizeBytes);
    expect(artifact.sha256, MiganModelEvidence.artifactSha256);
    expect(artifact.sources.single.url, MiganModelEvidence.artifactUrl);
    expect(descriptor.engineIds, contains('onnx-migan-inpaint'));
    expect(descriptor.licenseName, contains('metadata unset'));
    expect(descriptor.supportsImages, isFalse);
  });

  test('official CTD ONNX release is pinned as a runtime download', () {
    final ModelDescriptor descriptor =
        OnnxModelCatalog().find(OnnxModelStore.ctdDetectionManifestId)!;
    final ModelArtifactDescriptor artifact = descriptor.artifacts.single;
    expect(artifact.sizeBytes, CtdModelEvidence.artifactSizeBytes);
    expect(artifact.sha256, CtdModelEvidence.artifactSha256);
    expect(artifact.sources.single.url, CtdModelEvidence.artifactUrl);
    expect(descriptor.engineIds, contains('ctd-detection'));
    expect(descriptor.licenseName, contains('GPL-3.0-only'));
  });
}

extension on File {
  Future<String> sha256ForTest() async =>
      (await sha256.bind(openRead()).first).toString();
}
