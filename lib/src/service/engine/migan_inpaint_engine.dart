import '../inference/inference_exception.dart';
import '../inference/inference_task.dart';
import '../inference/inpainting_inference_engine.dart';
import 'engine_contract.dart';

class MiganOnnxInpaintEngineAdapter implements InpaintEngine {
  MiganOnnxInpaintEngineAdapter({
    required InpaintingInferenceEngine Function() resolver,
  }) : _resolver = resolver;

  final InpaintingInferenceEngine Function() _resolver;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'onnx-migan-inpaint',
    kind: EngineKind.inpaint,
    displayName: 'MI-GAN Pipeline V2 inpainting',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
    modelId: 'migan-pipeline-v2',
  );

  @override
  bool get isReady => _resolver().isReady;

  @override
  EngineTask<String> inpaint(ImageProcessingRequest request) =>
      EngineTask<String>.start(
        operation: (EngineTaskContext context) async {
          if (request.polygonMasks.isEmpty) {
            throw EngineException(
              code: 'polygon_mask_required',
              message: 'Inpainting requires CTD polygon masks.',
              engineId: descriptor.id,
            );
          }
          final InferenceCancellationToken token = InferenceCancellationToken();
          final subscription = context.cancellation.onCancel.listen(
            token.cancel,
          );
          try {
            context.report(EngineTaskStage.processing, 0);
            await _resolver().inpaint(
              inputPath: request.imagePath,
              outputPath: request.outputPath,
              polygonMasks: request.polygonMasks,
              cancellationToken: token,
              onProgress: (double progress) =>
                  context.report(EngineTaskStage.processing, progress),
            );
            context.report(EngineTaskStage.finalizing, 0.98);
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
