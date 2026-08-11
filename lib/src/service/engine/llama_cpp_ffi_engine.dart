import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';

import 'engine_contract.dart';
import 'context_translation_contract.dart';
import 'gguf_model_store.dart';
import 'local_translation_prompt.dart';
import 'model_catalog.dart';

typedef _BridgeVersionNative = ffi.Int32 Function();
typedef _BridgeVersionDart = int Function();
typedef _TranslateJsonNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _TranslateJsonDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _FreeStringDart = void Function(ffi.Pointer<Utf8>);

/// Small, app-owned ABI boundary around the maintained upstream llama.cpp
/// revision. The app never binds the old fllama package. Until the native
/// bridge is compiled and exports all three symbols, this adapter is not ready
/// and local GGUF is not offered as runnable on mobile.
class LlamaCppFfiBridge {
  LlamaCppFfiBridge({ffi.DynamicLibrary? library}) : _injected = library;

  final ffi.DynamicLibrary? _injected;
  ffi.DynamicLibrary? _library;
  _BridgeVersionDart? _version;
  _TranslateJsonDart? _translate;
  _FreeStringDart? _free;
  bool _attempted = false;

  bool get isAvailable {
    _load();
    return _library != null &&
        _version != null &&
        _translate != null &&
        _free != null;
  }

  int? get version {
    if (!isAvailable) {
      return null;
    }
    try {
      return _version!();
    } on Object {
      return null;
    }
  }

  String translateJson(Map<String, dynamic> request) {
    if (!isAvailable || (version ?? 0) <= 0) {
      throw StateError('The llama.cpp FFI bridge is not loaded.');
    }
    final ffi.Pointer<Utf8> input = jsonEncode(request).toNativeUtf8();
    ffi.Pointer<Utf8>? output;
    try {
      output = _translate!(input);
      if (output.address == 0) {
        throw StateError('The llama.cpp FFI bridge returned a null response.');
      }
      return output.toDartString();
    } finally {
      calloc.free(input);
      if (output != null && output.address != 0) {
        _free!(output);
      }
    }
  }

  void _load() {
    if (_attempted) {
      return;
    }
    _attempted = true;
    try {
      final ffi.DynamicLibrary library =
          _injected ??
          (Platform.isAndroid
              ? ffi.DynamicLibrary.open('libjh_llama_bridge.so')
              : Platform.isIOS
              ? ffi.DynamicLibrary.process()
              : throw UnsupportedError('Mobile FFI is not active here.'));
      _library = library;
      _version = library
          .lookupFunction<_BridgeVersionNative, _BridgeVersionDart>(
            'jh_llama_bridge_version',
          );
      _translate = library
          .lookupFunction<_TranslateJsonNative, _TranslateJsonDart>(
            'jh_llama_translate_json',
          );
      _free = library.lookupFunction<_FreeStringNative, _FreeStringDart>(
        'jh_llama_free_string',
      );
    } on Object {
      _library = null;
      _version = null;
      _translate = null;
      _free = null;
    }
  }
}

class LlamaCppFfiTranslationEngine
    implements TranslationEngine, ContextTranslationEngine {
  LlamaCppFfiTranslationEngine({
    ImageTranslationSetting? setting,
    GgufModelStore? store,
    LlamaCppFfiBridge? bridge,
  }) : _setting = setting ?? imageTranslationSetting,
       _store = store ?? GgufModelStore.instance,
       _bridge = bridge ?? LlamaCppFfiBridge();

  final ImageTranslationSetting _setting;
  final GgufModelStore _store;
  final LlamaCppFfiBridge _bridge;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'llama-ffi-translation',
    kind: EngineKind.translation,
    displayName: 'Local GGUF · llama.cpp FFI',
    platforms: <EnginePlatform>{EnginePlatform.android, EnginePlatform.ios},
  );

  @override
  bool get isReady =>
      (Platform.isAndroid || Platform.isIOS) &&
      _bridge.isAvailable &&
      (_bridge.version ?? 0) > 0 &&
      _store.isInstalledSync(_setting.localModelId.value);

  @override
  EngineTask<TranslationResult> translate(
    TranslationEngineRequest request,
  ) => EngineTask.start(
    operation: (EngineTaskContext context) async {
      if (!isReady) {
        throw const EngineException(
          code: 'runtime_unavailable',
          message:
              'The maintained llama.cpp FFI bridge is not compiled/loaded on this device.',
          engineId: 'llama-ffi-translation',
        );
      }
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model =
          _store.catalog.find(modelId) ??
          (throw const EngineException(
            code: 'model_not_found',
            message: 'The selected GGUF is not in the verified catalog.',
            engineId: 'llama-ffi-translation',
          ));
      try {
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final LocalTranslationPrompt prompt = buildLocalTranslationPrompt(
          request.blocks,
          request.targetLanguage,
        );
        final String raw = _bridge.translateJson(<String, dynamic>{
          'modelPath': _store.artifactPath(modelId, model.artifacts.first.id),
          'projectorPath':
              model.imageProjectorArtifactId == null
                  ? null
                  : _store.artifactPath(
                    modelId,
                    model.imageProjectorArtifactId!,
                  ),
          'instruction': prompt.instruction,
          'prompt': prompt.prompt,
          'targetLanguage': request.targetLanguage,
          'sourceLines': prompt.sourceLines,
          'imagePath': request.imagePath,
        });
        final dynamic response = jsonDecode(raw);
        final List<String> lines = _linesFromResponse(
          response,
          prompt.sourceLines.length,
        );
        context.report(EngineTaskStage.finalizing, 0.98);
        return TranslationResult(
          translatedText: lines.join('\n'),
          lines: lines,
        );
      } on EngineException {
        rethrow;
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'ffi_failed',
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
      if (!isReady) {
        throw const EngineException(
          code: 'runtime_unavailable',
          message:
              'The maintained llama.cpp FFI bridge is not compiled/loaded on this device.',
          engineId: 'llama-ffi-translation',
        );
      }
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model =
          _store.catalog.find(modelId) ??
          (throw const EngineException(
            code: 'model_not_found',
            message: 'The selected GGUF is not in the verified catalog.',
            engineId: 'llama-ffi-translation',
          ));
      try {
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final LocalContextTranslationPrompt prompt =
            buildLocalContextTranslationPrompt(request);
        final String raw = _bridge.translateJson(<String, dynamic>{
          'modelPath': _store.artifactPath(modelId, model.artifacts.first.id),
          'instruction': prompt.instruction,
          'prompt': prompt.prompt,
          'targetLanguage': request.targetLanguage,
          'contextRequest': request.toJson(),
        });
        context.cancellation.throwIfCancelled();
        context.report(EngineTaskStage.finalizing, 0.98);
        dynamic response;
        try {
          response = jsonDecode(raw);
        } on FormatException {
          response = raw;
        }
        return parseLocalContextTranslationResponse(response);
      } on EngineException {
        rethrow;
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'ffi_failed',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );

  List<String> _linesFromResponse(dynamic response, int count) {
    if (response is Map && response['lines'] is List) {
      return (response['lines'] as List)
          .map((Object? line) => line?.toString() ?? '')
          .toList(growable: false);
    }
    final String? text =
        response is Map ? response['translatedText']?.toString() : null;
    if (text == null || text.trim().isEmpty) {
      throw StateError('The llama.cpp FFI bridge returned no translation.');
    }
    return parseLocalNumberedTranslations(stripLocalReasoning(text), count);
  }
}
