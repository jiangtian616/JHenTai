import 'engine_contract.dart';

const Set<EnginePlatform> allSupportedPlatforms = <EnginePlatform>{
  EnginePlatform.android,
  EnginePlatform.ios,
  EnginePlatform.linux,
  EnginePlatform.macos,
  EnginePlatform.windows,
};

class UnavailableDetectionEngine implements DetectionEngine {
  const UnavailableDetectionEngine();

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'detection-unavailable',
    kind: EngineKind.detection,
    displayName: 'Detection (not installed)',
    platforms: allSupportedPlatforms,
  );

  @override
  bool get isReady => false;

  @override
  EngineTask<DetectionResult> detect(EngineImageRequest request) =>
      EngineTask<DetectionResult>.start(
        operation: (EngineTaskContext context) async {
          throw const EngineException(
            code: 'not_implemented',
            message: 'No detection model is installed.',
            engineId: 'detection-unavailable',
          );
        },
      );
}

class UnavailableInpaintEngine implements InpaintEngine {
  const UnavailableInpaintEngine();

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'inpaint-unavailable',
    kind: EngineKind.inpaint,
    displayName: 'Inpainting (not installed)',
    platforms: allSupportedPlatforms,
  );

  @override
  bool get isReady => false;

  @override
  EngineTask<String> inpaint(ImageProcessingRequest request) =>
      EngineTask<String>.start(
        operation: (EngineTaskContext context) async {
          throw const EngineException(
            code: 'not_implemented',
            message: 'No inpainting model is installed.',
            engineId: 'inpaint-unavailable',
          );
        },
      );
}
