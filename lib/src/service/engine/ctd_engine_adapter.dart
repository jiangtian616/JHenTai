import 'engine_contract.dart';

/// The native/isolated CTD boundary. A concrete implementation is supplied
/// only after its model artifact, license and runtime are verified.
typedef CtdDetectionRunner =
    Future<CtdDetectionOutput> Function(
      String imagePath,
      EngineCancellationToken cancellation,
      void Function(double progress) onProgress,
    );

class CtdDetectionOutput {
  const CtdDetectionOutput({required this.polygonMasks});

  final List<PolygonMask> polygonMasks;
}

const Set<EnginePlatform> _ctdPlatforms = <EnginePlatform>{
  EnginePlatform.android,
  EnginePlatform.ios,
  EnginePlatform.linux,
  EnginePlatform.macos,
  EnginePlatform.windows,
};

/// CTD is registered as its own capability. With no verified runner the
/// adapter remains unavailable and reports a concrete error; it never turns a
/// detector rectangle into a pretend polygon mask.
class CtdDetectionEngineAdapter implements DetectionEngine {
  CtdDetectionEngineAdapter({this.runner});

  final CtdDetectionRunner? runner;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'ctd-detection',
    kind: EngineKind.detection,
    displayName: 'CTD comic text detector',
    platforms: _ctdPlatforms,
  );

  @override
  bool get isReady => runner != null;

  @override
  EngineTask<DetectionResult> detect(
    EngineImageRequest request,
  ) => EngineTask<DetectionResult>.start(
    operation: (EngineTaskContext context) async {
      final CtdDetectionRunner? run = runner;
      if (run == null) {
        throw EngineException(
          code: 'model_unavailable',
          message:
              'CTD has no verified model artifact or native runner installed.',
          engineId: descriptor.id,
        );
      }
      context.report(EngineTaskStage.loading, 0);
      final CtdDetectionOutput output = await run(
        request.imagePath,
        context.cancellation,
        (double progress) =>
            context.report(EngineTaskStage.processing, progress),
      );
      context.cancellation.throwIfCancelled();
      final List<PolygonMask> masks = output.polygonMasks
          .where((PolygonMask mask) => mask.isValid)
          .toList(growable: false);
      if (masks.length != output.polygonMasks.length) {
        throw EngineException(
          code: 'invalid_output',
          message: 'CTD returned an invalid polygon mask.',
          engineId: descriptor.id,
        );
      }
      context.report(EngineTaskStage.finalizing, 0.98);
      return DetectionResult(
        regions: masks.map(_regionFor).toList(growable: false),
        polygonMasks: masks,
      );
    },
  );

  static DetectedTextRegion _regionFor(PolygonMask mask) => DetectedTextRegion(
    left: mask.left,
    top: mask.top,
    width: (mask.right - mask.left).clamp(0, double.infinity),
    height: (mask.bottom - mask.top).clamp(0, double.infinity),
    confidence: mask.confidence,
  );
}
