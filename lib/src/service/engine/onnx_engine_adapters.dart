import 'dart:async';

import 'package:jhentai/src/service/inference/inference_exception.dart';
import 'package:jhentai/src/service/inference/inference_task.dart';
import 'package:jhentai/src/service/inference/ocr_inference_engine.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference/super_resolution_inference_engine.dart';

import 'engine_contract.dart';
import 'model_catalog.dart';

class OnnxOcrEngineAdapter implements OcrEngine {
  OnnxOcrEngineAdapter({required OcrInferenceEngine Function() resolver})
    : _resolver = resolver;

  final OcrInferenceEngine Function() _resolver;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'onnx-ocr',
    kind: EngineKind.ocr,
    displayName: 'ONNX OCR',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
    modelId: OnnxModelStore.ocrManifestId,
  );

  @override
  bool get isReady => _resolver().isReady;

  @override
  EngineTask<OcrResult> recognize(OcrEngineRequest request) =>
      EngineTask<OcrResult>.start(
        operation: (EngineTaskContext context) async {
          final InferenceCancellationToken token = InferenceCancellationToken();
          final subscription = context.cancellation.onCancel.listen(
            token.cancel,
          );
          try {
            context.report(EngineTaskStage.processing, 0);
            final OcrInferenceResult result = await _resolver().recognize(
              request.imagePath,
              maxDimension: request.maxDimension,
              cancellationToken: token,
              onProgress:
                  (double progress) =>
                      context.report(EngineTaskStage.processing, progress),
            );
            context.report(EngineTaskStage.finalizing, 0.98);
            return OcrResult(
              blocks: result.blocks,
              imageWidth: result.imageWidth,
              imageHeight: result.imageHeight,
            );
          } on InferenceCancelledException catch (error) {
            throw EngineTaskCancelledException(error.reason);
          } on InferenceNotReadyException catch (error) {
            throw EngineException(
              code: 'not_ready',
              message: error.toString(),
              engineId: descriptor.id,
              cause: error,
            );
          } finally {
            await subscription.cancel();
          }
        },
      );
}

class OnnxSuperResolutionEngineAdapter implements SuperResolutionEngine {
  OnnxSuperResolutionEngineAdapter({
    required SuperResolutionInferenceEngine Function() resolver,
  }) : _resolver = resolver;

  final SuperResolutionInferenceEngine Function() _resolver;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'onnx-super-resolution',
    kind: EngineKind.superResolution,
    displayName: 'ONNX Super Resolution',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
    modelId: OnnxModelStore.superResolutionManifestId,
  );

  @override
  bool get isReady => _resolver().isReady;

  @override
  EngineTask<String> upscale(ImageProcessingRequest request, {int scale = 4}) =>
      EngineTask<String>.start(
        operation: (EngineTaskContext context) async {
          final InferenceCancellationToken token = InferenceCancellationToken();
          final subscription = context.cancellation.onCancel.listen(
            token.cancel,
          );
          try {
            context.report(EngineTaskStage.processing, 0);
            await _resolver().upscale(
              inputPath: request.imagePath,
              outputPath: request.outputPath,
              scale: scale,
              cancellationToken: token,
              onProgress:
                  (double progress) =>
                      context.report(EngineTaskStage.processing, progress),
            );
            return request.outputPath;
          } on InferenceCancelledException catch (error) {
            throw EngineTaskCancelledException(error.reason);
          } on InferenceNotReadyException catch (error) {
            throw EngineException(
              code: 'not_ready',
              message: error.toString(),
              engineId: descriptor.id,
              cause: error,
            );
          } finally {
            await subscription.cancel();
          }
        },
      );
}

class OnnxModelCatalog extends ModelCatalog {
  OnnxModelCatalog({List<OnnxModelManifest>? manifests})
    : _manifests = manifests ?? OnnxModelStore.manifests;

  final List<OnnxModelManifest> _manifests;

  @override
  List<ModelDescriptor> get models => _manifests
      .map(
        (OnnxModelManifest manifest) => ModelDescriptor(
          id: manifest.id,
          kind: manifest.kind,
          version: manifest.version,
          displayName: manifest.displayName,
          description: manifest.description,
          licenseName: manifest.licenseName,
          licenseUrl: manifest.licenseUrl,
          sourceProjectUrl: manifest.sourceProjectUrl,
          engineIds: <String>[
            switch (manifest.kind) {
              'ocr' => 'onnx-ocr',
              'superResolution' => 'onnx-super-resolution',
              _ => 'onnx',
            },
          ],
          artifacts: manifest.files
              .map(
                (OnnxModelFile file) => ModelArtifactDescriptor(
                  id: file.id,
                  fileName: file.fileName,
                  sizeBytes: file.sizeBytes,
                  sha256: file.sha256,
                  sources: file.urls.entries
                      .map(
                        (MapEntry<OnnxModelSource, String> entry) =>
                            ModelSourceDescriptor(
                              id: entry.key.name,
                              url: entry.value,
                            ),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

class OnnxModelDownloadManager implements ModelDownloadManager {
  OnnxModelDownloadManager({OnnxModelStore? store})
    : _store = store ?? OnnxModelStore.instance;

  final OnnxModelStore _store;
  final Map<String, EngineTask<ModelInstallResult>> _tasks =
      <String, EngineTask<ModelInstallResult>>{};

  @override
  EngineTask<ModelInstallResult> download(String modelId, {String? sourceId}) {
    final EngineTask<ModelInstallResult> task = EngineTask.start(
      operation: (EngineTaskContext context) async {
        final OnnxModelSource? source =
            sourceId == null
                ? null
                : OnnxModelSource.values.cast<OnnxModelSource?>().firstWhere(
                  (OnnxModelSource? value) => value?.name == sourceId,
                  orElse: () => null,
                );
        final subscription = context.cancellation.onCancel.listen(
          (_) => _store.cancelDownload(),
        );
        try {
          await _store.downloadManifest(
            modelId,
            source: source,
            onProgress:
                (String _, int received, int total) => context.report(
                  EngineTaskStage.processing,
                  total == 0 ? 0 : received / total,
                ),
          );
          context.report(EngineTaskStage.finalizing, 1);
          return ModelInstallResult(
            modelId: modelId,
            state: ModelInstallState.ready,
          );
        } on StateError catch (error) {
          throw EngineException(
            code: 'download_failed',
            message: error.toString(),
            engineId: 'onnx-model-download',
            cause: error,
          );
        } finally {
          await subscription.cancel();
        }
      },
    );
    _tasks[task.id] = task;
    unawaited(
      task.future.then<void>(
        (_) => _tasks.remove(task.id),
        onError: (Object _, StackTrace __) => _tasks.remove(task.id),
      ),
    );
    return task;
  }

  @override
  EngineTask<ModelInstallResult> update(String modelId, {String? sourceId}) =>
      download(modelId, sourceId: sourceId);

  @override
  Future<void> cancel(String taskId) async {
    _tasks[taskId]?.cancel('model download cancelled');
    _store.cancelDownload();
  }

  @override
  Future<void> delete(String modelId) => _store.deleteManifest(modelId);
}
