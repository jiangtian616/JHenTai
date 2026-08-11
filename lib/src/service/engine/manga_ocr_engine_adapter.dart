import 'dart:async';

import 'engine_contract.dart';
import 'unavailable_engine_adapters.dart';

/// Independent manga-OCR adapter boundary.
///
/// The adapter is registered so selection and fallback have a stable engine
/// id, but it deliberately reports not-ready until the verified vocabulary,
/// model downloader and five-platform runtime are delivered. When invoked it
/// falls back to the existing OCR adapter, preserving the current workflow.
class MangaOcrEngineAdapter implements OcrEngine {
  MangaOcrEngineAdapter({OcrEngine Function()? fallbackResolver})
    : _fallbackResolver = fallbackResolver;

  final OcrEngine Function()? _fallbackResolver;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'manga-ocr',
    kind: EngineKind.ocr,
    displayName: 'manga-OCR (pending verified runtime)',
    platforms: allSupportedPlatforms,
  );

  /// False is intentional: the adapter must not make a blocked model look
  /// ready to the capability matrix or to settings UI.
  @override
  bool get isReady => false;

  @override
  EngineTask<OcrResult> recognize(
    OcrEngineRequest request,
  ) => EngineTask<OcrResult>.start(
    operation: (EngineTaskContext context) async {
      final OcrEngine? fallback = _fallbackResolver?.call();
      if (fallback == null || !fallback.isReady) {
        throw const EngineException(
          code: 'blocked_model_artifacts',
          message:
              'manga-OCR is blocked until all model hashes and the five-platform runtime are verified.',
          engineId: 'manga-ocr',
        );
      }
      final EngineTask<OcrResult> task = fallback.recognize(request);
      final StreamSubscription<EngineTaskProgress> progress = task.progress
          .listen(
            (EngineTaskProgress event) => context.report(
              event.stage,
              event.fraction,
              message: 'manga-OCR fallback: ${event.message ?? ''}'.trim(),
            ),
          );
      final StreamSubscription<String> cancellation = context
          .cancellation
          .onCancel
          .listen((String reason) => task.cancel(reason));
      try {
        return await task.future;
      } finally {
        await progress.cancel();
        await cancellation.cancel();
      }
    },
  );
}
