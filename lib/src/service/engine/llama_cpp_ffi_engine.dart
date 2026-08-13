import 'dart:async';
import 'dart:math' as math;

import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

import 'context_translation_contract.dart';
import 'engine_contract.dart';
import 'gguf_model_store.dart';
import 'local_translation_prompt.dart';
import 'model_catalog.dart';

/// The app-owned seam around the federated llama.cpp package.
///
/// Keeping this small makes the engine testable without loading a multi-GB
/// native model and gives every supported Flutter target the same request and
/// response contract.
abstract interface class LlamaCppRuntime {
  bool get isAvailable;

  Future<bool> ensureAvailable();

  Future<String> generate({
    required String modelPath,
    required String instruction,
    required String prompt,
    required int maxOutputTokens,
    String? mmprojPath,
    String? imagePath,
  });
}

/// Direct in-process llama.cpp runtime supplied by [lib_llama_cpp].
///
/// The published CPU artifacts cover Android, iOS, macOS, Linux and Windows.
/// GPU acceleration is deliberately not assumed here: a CPU-only baseline is
/// predictable on every target and prevents a platform from reporting ready
/// merely because an optional GPU backend happens to be installed.
class LibLlamaCppRuntime implements LlamaCppRuntime {
  LibLlamaCppRuntime({LibLlamaCppPlatform? platform}) : _platform = platform;

  final LibLlamaCppPlatform? _platform;
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> ensureAvailable() async {
    try {
      final LlamaCppLibraryDescriptor descriptor =
          await (_platform ?? LibLlamaCppPlatform.instance).resolveLibrary();
      final bool hasLoadableDescriptor =
          (descriptor.path?.isNotEmpty ?? false) ||
          (descriptor.lookupName?.isNotEmpty ?? false) ||
          descriptor.resolution == LlamaCppLibraryResolution.process;
      _available =
          hasLoadableDescriptor &&
          descriptor.capabilities.contains(LlamaCppLibraryCapability.cpu);
    } on Object {
      _available = false;
    }
    return _available;
  }

  @override
  Future<String> generate({
    required String modelPath,
    required String instruction,
    required String prompt,
    required int maxOutputTokens,
    String? mmprojPath,
    String? imagePath,
  }) async {
    final LlamaOpenAIClient client = LlamaOpenAIClient(
      models: <String, LlamaModelConfig>{
        'local': LlamaModelConfig(
          modelPath: modelPath,
          contextSize: 4096,
          // The bundled baseline is CPU-only on all five Flutter targets.
          gpuLayerCount: 0,
          mmprojPath: mmprojPath,
        ),
      },
    );
    final Object input =
        imagePath != null && mmprojPath != null
            ? <LlamaChatMessage>[
              LlamaChatMessage(
                role: 'user',
                content: <LlamaContentPart>[
                  LlamaTextPart(prompt),
                  LlamaImageFilePart(path: imagePath),
                ],
              ),
            ]
            : prompt;
    final LlamaResponseObject response = await client.responses.create(
      model: 'local',
      input: input,
      instructions: instruction,
      maxOutputTokens: maxOutputTokens,
      temperature: 0.2,
      topP: 0.9,
    );
    return response.outputText;
  }
}

/// Unified local GGUF translation for Android, iOS, macOS, Windows and Linux.
///
/// The old implementation looked for app-specific `jh_llama_bridge_*`
/// symbols. No target actually shipped that bridge, so a downloaded model
/// could never become runnable. This adapter now uses the same in-process
/// llama.cpp ABI on every supported target and performs an async native
/// readiness probe before the capability matrix is evaluated.
class LlamaCppFfiTranslationEngine
    implements TranslationEngine, ContextTranslationEngine, EngineReadiness {
  LlamaCppFfiTranslationEngine({
    ImageTranslationSetting? setting,
    GgufModelStore? store,
    LlamaCppRuntime? runtime,
  }) : _setting = setting ?? imageTranslationSetting,
       _store = store ?? GgufModelStore.instance,
       _runtime = runtime ?? LibLlamaCppRuntime();

  final ImageTranslationSetting _setting;
  final GgufModelStore _store;
  final LlamaCppRuntime _runtime;

  // A local model load is expensive. Serializing requests also prevents OCR,
  // context translation and gallery translation from loading duplicate GGUF
  // sessions at the same time and recreating the previous memory-pressure
  // failure mode.
  static Future<void> _inferenceTail = Future<void>.value();

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'llama-ffi-translation',
    kind: EngineKind.translation,
    displayName: 'Local GGUF · llama.cpp (all platforms)',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
  );

  @override
  bool get isReady =>
      _runtime.isAvailable &&
      _store.isInstalledSync(_setting.localModelId.value);

  @override
  Future<bool> ensureReady() async {
    final String modelId = _setting.localModelId.value;
    if (_store.catalog.find(modelId) == null ||
        !_store.isInstalledSync(modelId)) {
      return false;
    }
    return _runtime.ensureAvailable();
  }

  @override
  EngineTask<TranslationResult> translate(
    TranslationEngineRequest request,
  ) => EngineTask<TranslationResult>.start(
    operation: (EngineTaskContext context) async {
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model = _model(modelId);
      try {
        if (!await ensureReady()) {
          throw const EngineException(
            code: 'runtime_unavailable',
            message:
                'The bundled llama.cpp native runtime is not available on this target.',
            engineId: 'llama-ffi-translation',
          );
        }
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final LocalTranslationPrompt prompt = buildLocalTranslationPrompt(
          request.blocks,
          request.targetLanguage,
          mergeTextBlocks: request.mergeTextBlocks,
          containers: request.containers,
        );
        final String raw = await _runExclusive<String>(() async {
          context.cancellation.throwIfCancelled();
          return _runtime.generate(
            modelPath: _store.artifactPath(modelId, model.artifacts.first.id),
            mmprojPath:
                model.imageProjectorArtifactId == null
                    ? null
                    : _store.artifactPath(
                      modelId,
                      model.imageProjectorArtifactId!,
                    ),
            instruction: prompt.instruction,
            prompt: prompt.prompt,
            maxOutputTokens: _maxOutputTokens(prompt.sourceLines.length),
            imagePath:
                model.supportsImages && model.imageProjectorArtifactId != null
                    ? request.imagePath
                    : null,
          );
        });
        context.cancellation.throwIfCancelled();
        final List<RecognizedTextGroup> groups = translationTextGroups(
          request.blocks,
          merge: request.mergeTextBlocks,
          containers: request.containers,
        );
        final List<String> groupTranslations = parseNumberedTranslations(
          stripLocalReasoning(raw),
          groups.length,
          legacyCount: prompt.sourceLines.length,
        );
        final List<String> lines = expandGroupTranslationsToLines(
          blocks: request.blocks,
          groups: groups,
          groupTranslations: groupTranslations,
        );
        if (lines.every((String line) => line.trim().isEmpty)) {
          throw const FormatException(
            'The local llama.cpp runtime returned no translation.',
          );
        }
        context.report(EngineTaskStage.finalizing, 0.98);
        return TranslationResult(
          translatedText: lines.join('\n'),
          lines: lines,
          groupTranslations: groupTranslations,
        );
      } on EngineException {
        rethrow;
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'native_inference_failed',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );

  @override
  EngineTask<ContextTranslationResult> translateContext(
    ContextTranslationEngineRequest request,
  ) => EngineTask<ContextTranslationResult>.start(
    operation: (EngineTaskContext context) async {
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model = _model(modelId);
      try {
        if (!await ensureReady()) {
          throw const EngineException(
            code: 'runtime_unavailable',
            message:
                'The bundled llama.cpp native runtime is not available on this target.',
            engineId: 'llama-ffi-translation',
          );
        }
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final LocalContextTranslationPrompt prompt =
            buildLocalContextTranslationPrompt(request);
        final String raw = await _runExclusive<String>(() async {
          context.cancellation.throwIfCancelled();
          return _runtime.generate(
            modelPath: _store.artifactPath(modelId, model.artifacts.first.id),
            instruction: prompt.instruction,
            prompt: prompt.prompt,
            maxOutputTokens: 2048,
          );
        });
        context.cancellation.throwIfCancelled();
        context.report(EngineTaskStage.finalizing, 0.98);
        return parseLocalContextTranslationResponse(stripLocalReasoning(raw));
      } on EngineException {
        rethrow;
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'native_inference_failed',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );

  ModelDescriptor _model(String modelId) =>
      _store.catalog.find(modelId) ??
      (throw const EngineException(
        code: 'model_not_found',
        message: 'The selected GGUF is not in the verified catalog.',
        engineId: 'llama-ffi-translation',
      ));

  static int _maxOutputTokens(int lineCount) =>
      math.min(2048, math.max(128, lineCount * 96));

  static Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final Future<void> previous = _inferenceTail;
    final Completer<void> release = Completer<void>();
    _inferenceTail = release.future;
    return previous.then((_) => operation()).whenComplete(() {
      if (!release.isCompleted) {
        release.complete();
      }
    });
  }
}
