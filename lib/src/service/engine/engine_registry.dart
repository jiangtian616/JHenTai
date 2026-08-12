import 'dart:io';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:jhentai/src/service/inference_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';

import 'api_translation_engine.dart';
import 'apple_engine_adapters.dart';
import 'ctd_engine_adapter.dart';
import 'bubble_segmentation_engine_adapter.dart';
import 'context_translation_contract.dart';
import 'engine_contract.dart';
import 'gguf_model_store.dart';
import 'llama_cpp_ffi_engine.dart';
import 'llama_server_translation_engine.dart';
import 'local_translation_model_catalog.dart';
import 'migan_inpaint_engine.dart';
import 'model_catalog.dart';
import 'manga_ocr_engine_adapter.dart';
import 'onnx_engine_adapters.dart';
import '../inference/inpainting_inference_engine.dart';
import '../inference/ctd_onnx_inference_engine.dart';
import '../inference/bubble_segmentation_inference_engine.dart';
import '../inference/inference_task.dart';
import '../inference/inference_safety.dart';
import '../inference/onnx_model_store.dart';
import '../inference/onnx_runtime.dart';

EnginePlatform get currentEnginePlatform {
  if (Platform.isAndroid) {
    return EnginePlatform.android;
  }
  if (Platform.isIOS) {
    return EnginePlatform.ios;
  }
  if (Platform.isLinux) {
    return EnginePlatform.linux;
  }
  if (Platform.isMacOS) {
    return EnginePlatform.macos;
  }
  if (Platform.isWindows) {
    return EnginePlatform.windows;
  }
  return EnginePlatform.unknown;
}

class EngineCapabilityDecision {
  const EngineCapabilityDecision({
    required this.supported,
    required this.reason,
  });

  final bool supported;
  final String reason;
}

/// Capability is calculated from registered adapters. There is no OCR-specific
/// translation branch here, so a future adapter can be added without changing
/// the read-page service or pretending an unavailable model exists.
class EngineCapabilityMatrix {
  const EngineCapabilityMatrix();

  EngineCapabilityDecision evaluate({
    required OcrEngine? ocr,
    required TranslationEngine? translation,
    EnginePlatform? platform,
  }) {
    if (ocr == null || translation == null) {
      return const EngineCapabilityDecision(
        supported: false,
        reason: 'Required engine adapter is not registered.',
      );
    }
    final EnginePlatform resolvedPlatform = platform ?? currentEnginePlatform;
    if (!ocr.descriptor.supports(resolvedPlatform) ||
        !translation.descriptor.supports(resolvedPlatform)) {
      return const EngineCapabilityDecision(
        supported: false,
        reason:
            'The selected engine combination is unavailable on this platform.',
      );
    }
    if (!ocr.isReady || !translation.isReady) {
      return const EngineCapabilityDecision(
        supported: false,
        reason: 'The selected engine is not ready for execution.',
      );
    }
    return const EngineCapabilityDecision(
      supported: true,
      reason: 'The selected OCR and translation engines can be composed.',
    );
  }
}

class EngineRegistry {
  EngineRegistry({
    InferenceService Function()? inferenceResolver,
    ImageTranslationSetting? setting,
    CtdDetectionRunner? ctdRunner,
    BubbleDetectionRunner? bubbleRunner,
    DetectionEngine? detectionEngine,
    DetectionEngine? bubbleDetectionEngine,
    InpaintEngine? inpaintEngine,
    this.capabilityMatrix = const EngineCapabilityMatrix(),
  }) : _inferenceResolver = inferenceResolver ?? (() => inferenceService),
       _setting = setting ?? imageTranslationSetting {
    registerOcr(
      OnnxOcrEngineAdapter(resolver: () => _inferenceResolver().ocrEngine),
    );
    registerOcr(
      MangaOcrEngineAdapter(fallbackResolver: () => _ocr['onnx-ocr']!),
    );
    registerOcr(AppleLiveTextOcrEngine());
    final ApiTranslationEngine apiTranslation = ApiTranslationEngine(
      setting: _setting,
    );
    registerTranslation(apiTranslation);
    registerContextTranslation(apiTranslation);
    registerTranslation(AppleTranslationEngine());
    final LlamaServerTranslationEngine llamaServer =
        LlamaServerTranslationEngine(setting: _setting);
    registerTranslation(llamaServer);
    registerContextTranslation(llamaServer);
    final LlamaCppFfiTranslationEngine llamaFfi = LlamaCppFfiTranslationEngine(
      setting: _setting,
    );
    registerTranslation(llamaFfi);
    registerContextTranslation(llamaFfi);
    registerSuperResolution(
      OnnxSuperResolutionEngineAdapter(
        resolver: () => _inferenceResolver().superResolutionEngine,
      ),
    );
    final CtdOnnxInferenceEngine ctdInference = CtdOnnxInferenceEngine(
      runtime: OnnxRuntime.instance,
      providerResolver: () {
        final List<ort.OrtProvider> available =
            OnnxRuntime.instance.availableProviders;
        return available.contains(ort.OrtProvider.CPU)
            ? <ort.OrtProvider>[ort.OrtProvider.CPU]
            : const <ort.OrtProvider>[];
      },
      modelResolver: () {
        final Map<String, String>? files = OnnxModelStore.instance
            .manifestFilePaths(OnnxModelStore.ctdDetectionManifestId);
        return CtdOnnxModelInfo(
          modelPath: files?['model'],
          fingerprint:
              OnnxModelStore.instance.fingerprintOf(
                OnnxModelStore.ctdDetectionManifestId,
              ) ??
              '',
        );
      },
    );
    registerDetection(
      detectionEngine ??
          CtdDetectionEngineAdapter(
            ready: ctdRunner == null ? () => ctdInference.isReady : null,
            runner:
                ctdRunner ??
                (
                  String imagePath,
                  EngineCancellationToken cancellation,
                  void Function(double progress) onProgress,
                ) async {
                  final InferenceCancellationToken token =
                      InferenceCancellationToken();
                  final subscription = cancellation.onCancel.listen(
                    token.cancel,
                  );
                  try {
                    return await ctdInference.detect(
                      imagePath,
                      cancellationToken: token,
                      onProgress: onProgress,
                    );
                  } finally {
                    await subscription.cancel();
                  }
                },
          ),
    );
    final BubbleSegmentationInferenceEngine bubbleInference =
        BubbleSegmentationInferenceEngine(
          runtime: OnnxRuntime.instance,
          providerResolver: () {
            final List<ort.OrtProvider> available =
                OnnxRuntime.instance.availableProviders;
            return available.contains(ort.OrtProvider.CPU)
                ? <ort.OrtProvider>[ort.OrtProvider.CPU]
                : const <ort.OrtProvider>[];
          },
          modelResolver: () {
            final Map<String, String>? files = OnnxModelStore.instance
                .manifestFilePaths(
                  OnnxModelStore.bubbleSegmentationManifestId,
                );
            return BubbleSegmentationModelInfo(
              modelPath: files?['model'],
              fingerprint: OnnxModelStore.instance.fingerprintOf(
                    OnnxModelStore.bubbleSegmentationManifestId,
                  ) ??
                  '',
            );
          },
        );
    registerDetection(
      bubbleDetectionEngine ??
          BubbleSegmentationEngineAdapter(
            ready: bubbleRunner == null ? () => bubbleInference.isReady : null,
            runner:
                bubbleRunner ??
                (
                  String imagePath,
                  EngineCancellationToken cancellation,
                  void Function(double progress) onProgress,
                ) async {
                  final InferenceCancellationToken token =
                      InferenceCancellationToken();
                  final subscription = cancellation.onCancel.listen(
                    token.cancel,
                  );
                  try {
                    return await bubbleInference.detect(
                      imagePath,
                      cancellationToken: token,
                      onProgress: onProgress,
                    );
                  } finally {
                    await subscription.cancel();
                  }
                },
          ),
    );
    final MiganOnnxInpaintingInferenceEngine miganInference =
        MiganOnnxInpaintingInferenceEngine(
          runtime: OnnxRuntime.instance,
          // CPU is the only provider enabled by this adapter until a CTD/
          // inpainting-specific canary is wired into InferenceService.
          providerResolver: () {
            final List<ort.OrtProvider> available =
                OnnxRuntime.instance.availableProviders;
            return available.contains(ort.OrtProvider.CPU)
                ? <ort.OrtProvider>[ort.OrtProvider.CPU]
                : const <ort.OrtProvider>[];
          },
          modelResolver: () {
            final Map<String, String>? files = OnnxModelStore.instance
                .manifestFilePaths(OnnxModelStore.miganInpaintManifestId);
            return MiganOnnxModelInfo(
              modelPath: files?['model'],
              fingerprint:
                  OnnxModelStore.instance.fingerprintOf(
                    OnnxModelStore.miganInpaintManifestId,
                  ) ??
                  '',
            );
          },
          safetyConfig: const InferenceSessionSafetyConfig(
            useArena: false,
            providerOptions: <String, Map<String, String>>{},
            sessionConfigEntries: <String, String>{
              'session.enable_cpu_mem_arena': '0',
            },
            requireStaticShapes: false,
            memoryBudgetBytes: 512 * 1024 * 1024,
            maxInputPixels: 12 * 1024 * 1024,
          ),
        );
    registerInpaint(
      inpaintEngine ??
          MiganOnnxInpaintEngineAdapter(resolver: () => miganInference),
    );
    final OnnxModelCatalog onnxCatalog = OnnxModelCatalog();
    final OnnxModelDownloadManager onnxDownloads = OnnxModelDownloadManager();
    final LocalTranslationModelCatalog localCatalog =
        LocalTranslationModelCatalog();
    final GgufModelDownloadManager localDownloads = GgufModelDownloadManager();
    _modelCatalog = CompositeModelCatalog(<ModelCatalog>[
      onnxCatalog,
      localCatalog,
    ]);
    _modelDownloadManager = CompositeModelDownloadManager(
      catalog: _modelCatalog,
      routes: <String, ModelDownloadManager>{
        for (final ModelDescriptor model in onnxCatalog.models)
          model.id: onnxDownloads,
        for (final ModelDescriptor model in localCatalog.models)
          model.id: localDownloads,
      },
    );
  }

  final InferenceService Function() _inferenceResolver;
  final ImageTranslationSetting _setting;
  final EngineCapabilityMatrix capabilityMatrix;
  final Map<String, OcrEngine> _ocr = <String, OcrEngine>{};
  final Map<String, TranslationEngine> _translations =
      <String, TranslationEngine>{};
  final Map<String, ContextTranslationEngine> _contextTranslations =
      <String, ContextTranslationEngine>{};
  final Map<String, DetectionEngine> _detection = <String, DetectionEngine>{};
  final Map<String, InpaintEngine> _inpaint = <String, InpaintEngine>{};
  final Map<String, SuperResolutionEngine> _superResolution =
      <String, SuperResolutionEngine>{};
  late final ModelCatalog _modelCatalog;
  late final ModelDownloadManager _modelDownloadManager;

  void registerOcr(OcrEngine engine) =>
      _put(_ocr, engine.descriptor.id, engine);
  void registerTranslation(TranslationEngine engine) =>
      _put(_translations, engine.descriptor.id, engine);
  void registerContextTranslation(ContextTranslationEngine engine) =>
      _put(_contextTranslations, engine.descriptor.id, engine);
  void registerDetection(DetectionEngine engine) =>
      _put(_detection, engine.descriptor.id, engine);
  void registerInpaint(InpaintEngine engine) =>
      _put(_inpaint, engine.descriptor.id, engine);
  void registerSuperResolution(SuperResolutionEngine engine) =>
      _put(_superResolution, engine.descriptor.id, engine);

  void _put<T>(Map<String, T> target, String id, T engine) {
    if (target.containsKey(id)) {
      throw StateError('Engine adapter already registered: $id');
    }
    target[id] = engine;
  }

  OcrEngine? findOcr(String id) => _ocr[id];
  TranslationEngine? findTranslation(String id) => _translations[id];
  ContextTranslationEngine? findContextTranslation(String id) =>
      _contextTranslations[id];
  DetectionEngine? findDetection(String id) => _detection[id];
  InpaintEngine? findInpaint(String id) => _inpaint[id];
  SuperResolutionEngine? findSuperResolution(String id) => _superResolution[id];
  ModelCatalog get modelCatalog => _modelCatalog;
  ModelDownloadManager get modelDownloadManager => _modelDownloadManager;

  OcrEngine get selectedOcr {
    final String id = switch (_setting.ocrEngine.value) {
      ImageOcrEngine.appleLiveText => 'apple-live-text-ocr',
      ImageOcrEngine.onnx => 'onnx-ocr',
      ImageOcrEngine.mangaOcr => 'manga-ocr',
    };
    return _ocr[id]!;
  }

  TranslationEngine get selectedTranslation {
    final String id = switch (_setting.translatorEngine.value) {
      ImageTranslationEngine.appleOnDevice => 'apple-translation',
      ImageTranslationEngine.api => 'api-translation',
      // The federated llama.cpp FFI runtime is the single local-GGUF path on
      // every supported target. The server adapter remains registered for
      // compatibility with older desktop settings, but is not selected for
      // new work and therefore cannot make mobile/desktop behavior diverge.
      ImageTranslationEngine.localGguf => 'llama-ffi-translation',
    };
    return _translations[id]!;
  }

  /// Context translation is an independent capability. A regular
  /// [TranslationEngine] is never treated as context-capable implicitly.
  ContextTranslationEngine? get selectedContextTranslation =>
      findContextTranslation(selectedTranslation.descriptor.id);

  EngineCapabilityDecision evaluateSelected({EnginePlatform? platform}) =>
      capabilityMatrix.evaluate(
        ocr: selectedOcr,
        translation: selectedTranslation,
        platform: platform,
      );
}

final EngineRegistry engineRegistry = EngineRegistry();
