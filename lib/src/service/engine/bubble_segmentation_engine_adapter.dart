import '../inference/bubble_segmentation_inference_engine.dart';
import '../inference/inference_exception.dart';
import '../inference/inference_task.dart';
import 'engine_contract.dart';

typedef BubbleDetectionRunner = Future<DetectionResult> Function(
  String imagePath,
  EngineCancellationToken cancellation,
  void Function(double progress) onProgress,
);

class BubbleSegmentationEngineAdapter implements DetectionEngine {
  BubbleSegmentationEngineAdapter({this.runner, bool Function()? ready})
    : _ready = ready;

  final BubbleDetectionRunner? runner;
  final bool Function()? _ready;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'manga109-bubble-segmentation',
    kind: EngineKind.detection,
    displayName: 'Manga109 speech-bubble segmentation',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
    modelId: 'manga109-segmentation-bubble-onnx',
  );

  @override
  bool get isReady => runner != null && (_ready?.call() ?? true);

  @override
  EngineTask<DetectionResult> detect(EngineImageRequest request) =>
      EngineTask<DetectionResult>.start(
        operation: (EngineTaskContext context) async {
          final BubbleDetectionRunner? run = runner;
          if (run == null) {
            throw EngineException(
              code: 'model_unavailable',
              message: 'Manga109 bubble segmentation is not installed.',
              engineId: descriptor.id,
            );
          }
          try {
            context.report(EngineTaskStage.loading, 0);
            final DetectionResult result = await run(
              request.imagePath,
              context.cancellation,
              (double progress) =>
                  context.report(EngineTaskStage.processing, progress),
            );
            context.cancellation.throwIfCancelled();
            context.report(EngineTaskStage.finalizing, 0.98);
            return result;
          } on InferenceCancelledException catch (error) {
            throw EngineTaskCancelledException(error.reason);
          } on InferenceNotReadyException catch (error) {
            throw EngineException(
              code: 'not_ready',
              message: error.toString(),
              engineId: descriptor.id,
              cause: error,
            );
          }
        },
      );
}
