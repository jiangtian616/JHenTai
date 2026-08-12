import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

import 'engine_contract.dart';
import 'context_translation_contract.dart';
import 'gguf_model_store.dart';
import 'llama_runtime_store.dart';
import 'local_translation_prompt.dart';
import 'model_catalog.dart';

/// Desktop-only adapter. Each translation owns a localhost llama-server
/// process; a server crash is therefore contained to the current task and the
/// runtime binary can be upgraded independently of the Flutter bundle.
class LlamaServerTranslationEngine
    implements TranslationEngine, ContextTranslationEngine {
  LlamaServerTranslationEngine({
    ImageTranslationSetting? setting,
    GgufModelStore? store,
    LlamaRuntimeStore? runtimeStore,
    HttpClient? client,
  }) : _setting = setting ?? imageTranslationSetting,
       _store = store ?? GgufModelStore.instance,
       _runtimeStore = runtimeStore ?? LlamaRuntimeStore.instance,
       _client = client ?? HttpClient();

  final ImageTranslationSetting _setting;
  final GgufModelStore _store;
  final LlamaRuntimeStore _runtimeStore;
  final HttpClient _client;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'llama-server-translation',
    kind: EngineKind.translation,
    displayName: 'Local GGUF · llama-server',
    platforms: <EnginePlatform>{
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
    },
  );

  @override
  bool get isReady =>
      _isDesktop &&
      _resolveExecutable() != null &&
      _store.isInstalledSync(_setting.localModelId.value);

  @override
  EngineTask<TranslationResult> translate(
    TranslationEngineRequest request,
  ) => EngineTask<TranslationResult>.start(
    operation: (EngineTaskContext context) async {
      if (!_isDesktop) {
        throw const EngineException(
          code: 'unsupported_platform',
          message: 'llama-server is only used on desktop platforms.',
          engineId: 'llama-server-translation',
        );
      }
      final String? executable = _resolveExecutable();
      if (executable == null) {
        throw const EngineException(
          code: 'runtime_unavailable',
          message:
              'Configure a verified llama-server executable before selecting a local GGUF.',
          engineId: 'llama-server-translation',
        );
      }
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model =
          _store.catalog.find(modelId) ??
          (throw const EngineException(
            code: 'model_not_found',
            message: 'The selected GGUF is not in the verified catalog.',
            engineId: 'llama-server-translation',
          ));
      try {
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final int port = await _reservePort();
        final List<String> arguments = <String>[
          '-m',
          _store.artifactPath(modelId, model.artifacts.first.id),
          '--host',
          '127.0.0.1',
          '--port',
          '$port',
          '--parallel',
          '1',
        ];
        if (model.imageProjectorArtifactId != null) {
          arguments.addAll(<String>[
            '--mmproj',
            _store.artifactPath(modelId, model.imageProjectorArtifactId!),
          ]);
        }
        final Process process = await Process.start(executable, arguments);
        // Drain both pipes so a verbose server cannot block on a full pipe.
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        try {
          context.report(EngineTaskStage.loading, 0.15);
          await _waitUntilHealthy(process, port, context.cancellation);
          context.report(EngineTaskStage.processing, 0.35);
          final LocalTranslationPrompt prompt = buildLocalTranslationPrompt(
            request.blocks,
            request.targetLanguage,
            mergeTextBlocks: request.mergeTextBlocks,
            containers: request.containers,
          );
          final dynamic response = await _complete(
            port,
            modelId,
            prompt,
            request,
            model,
            context.cancellation,
          );
          final String? content = _contentFromResponse(response);
          if (content == null || content.trim().isEmpty) {
            throw const EngineException(
              code: 'invalid_response',
              message: 'llama-server returned no translation text.',
              engineId: 'llama-server-translation',
            );
          }
      final List<RecognizedTextGroup> groups = translationTextGroups(
        request.blocks,
        merge: request.mergeTextBlocks,
        containers: request.containers,
      );
          final List<String> groupTranslations = parseNumberedTranslations(
            stripLocalReasoning(content),
            groups.length,
            legacyCount: prompt.sourceLines.length,
          );
          final List<String> lines = expandGroupTranslationsToLines(
            blocks: request.blocks,
            groups: groups,
            groupTranslations: groupTranslations,
          );
          context.report(EngineTaskStage.finalizing, 0.98);
          return TranslationResult(
            translatedText: lines.join('\n'),
            lines: lines,
            groupTranslations: groupTranslations,
          );
        } finally {
          process.kill();
          await Future.any<void>(<Future<void>>[
            process.exitCode.then<void>((int _) {}),
            Future<void>.delayed(const Duration(seconds: 2)),
          ]);
        }
      } on EngineException {
        rethrow;
      } on ProcessException catch (error) {
        throw EngineException(
          code: 'process_start_failed',
          message: error.message,
          engineId: descriptor.id,
          cause: error,
        );
      } on TimeoutException catch (error) {
        throw EngineException(
          code: 'server_timeout',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'server_failed',
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
      if (!_isDesktop) {
        throw const EngineException(
          code: 'unsupported_platform',
          message: 'llama-server is only used on desktop platforms.',
          engineId: 'llama-server-translation',
        );
      }
      final String? executable = _resolveExecutable();
      if (executable == null) {
        throw const EngineException(
          code: 'runtime_unavailable',
          message:
              'Configure a verified llama-server executable before selecting a local GGUF.',
          engineId: 'llama-server-translation',
        );
      }
      final String modelId = _setting.localModelId.value;
      final ModelDescriptor model =
          _store.catalog.find(modelId) ??
          (throw const EngineException(
            code: 'model_not_found',
            message: 'The selected GGUF is not in the verified catalog.',
            engineId: 'llama-server-translation',
          ));
      try {
        context.report(EngineTaskStage.loading, 0.05);
        await _store.validateInstalled(modelId);
        context.cancellation.throwIfCancelled();
        final int port = await _reservePort();
        final Process process = await Process.start(executable, <String>[
          '-m',
          _store.artifactPath(modelId, model.artifacts.first.id),
          '--host',
          '127.0.0.1',
          '--port',
          '$port',
          '--parallel',
          '1',
        ]);
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        try {
          context.report(EngineTaskStage.loading, 0.15);
          await _waitUntilHealthy(process, port, context.cancellation);
          context.report(EngineTaskStage.processing, 0.35);
          final LocalContextTranslationPrompt prompt =
              buildLocalContextTranslationPrompt(request);
          final dynamic response = await _completeContext(
            port,
            modelId,
            prompt,
            request,
            context.cancellation,
          );
          final String? content = _contentFromResponse(response);
          if (content == null || content.trim().isEmpty) {
            throw const EngineException(
              code: 'invalid_response',
              message: 'llama-server returned no context translation.',
              engineId: 'llama-server-translation',
            );
          }
          context.report(EngineTaskStage.finalizing, 0.98);
          return parseLocalContextTranslationResponse(content);
        } finally {
          process.kill();
          await Future.any<void>(<Future<void>>[
            process.exitCode.then<void>((int _) {}),
            Future<void>.delayed(const Duration(seconds: 2)),
          ]);
        }
      } on EngineException {
        rethrow;
      } on ProcessException catch (error) {
        throw EngineException(
          code: 'process_start_failed',
          message: error.message,
          engineId: descriptor.id,
          cause: error,
        );
      } on TimeoutException catch (error) {
        throw EngineException(
          code: 'server_timeout',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      } on Object catch (error) {
        if (context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'server_failed',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );

  Future<void> _waitUntilHealthy(
    Process process,
    int port,
    EngineCancellationToken cancellation,
  ) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      cancellation.throwIfCancelled();
      try {
        final HttpClientRequest request = await _client.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        final HttpClientResponse response = await request.close().timeout(
          const Duration(seconds: 2),
        );
        await response.drain<void>();
        if (response.statusCode == HttpStatus.ok) {
          return;
        }
      } on Object {
        // The server is still loading the GGUF; retry until the hard deadline.
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw TimeoutException('llama-server health check timed out.');
  }

  Future<dynamic> _complete(
    int port,
    String modelId,
    LocalTranslationPrompt prompt,
    TranslationEngineRequest request,
    ModelDescriptor model,
    EngineCancellationToken cancellation,
  ) async {
    final Map<String, dynamic> userMessage = <String, dynamic>{
      'role': 'user',
      'content': await _messageContent(prompt.prompt, request, model),
    };
    final HttpClientRequest httpRequest = await _client.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/chat/completions'),
    );
    httpRequest.headers.contentType = ContentType.json;
    httpRequest.write(
      jsonEncode(<String, dynamic>{
        'model': modelId,
        'temperature': 0.2,
        'max_tokens': 2048,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{'role': 'system', 'content': prompt.instruction},
          userMessage,
        ],
        'stream': false,
      }),
    );
    final HttpClientResponse response = await httpRequest.close().timeout(
      const Duration(seconds: 90),
    );
    final String body = await utf8.decoder.bind(response).join();
    cancellation.throwIfCancelled();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('llama-server HTTP ${response.statusCode}: $body');
    }
    return jsonDecode(body);
  }

  Future<dynamic> _completeContext(
    int port,
    String modelId,
    LocalContextTranslationPrompt prompt,
    ContextTranslationEngineRequest request,
    EngineCancellationToken cancellation,
  ) async {
    final int lineCount = request.pages.fold<int>(
      0,
      (int total, ContextTranslationPageRequest page) =>
          total + page.lines.length,
    );
    final int maxTokens = (lineCount * 128 + 512).clamp(2048, 8192);
    // NB: llama-server models often have a smaller context window than the
    // API models; a request whose prompt + max_tokens exceeds n_ctx returns
    // HTTP 400. The reader's per-page fallback absorbs that failure.
    final HttpClientRequest httpRequest = await _client.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/chat/completions'),
    );
    httpRequest.headers.contentType = ContentType.json;
    httpRequest.write(
      jsonEncode(<String, dynamic>{
        'model': modelId,
        'temperature': 0.2,
        'max_tokens': maxTokens,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': prompt.instruction},
          <String, String>{'role': 'user', 'content': prompt.prompt},
        ],
        'stream': false,
      }),
    );
    final HttpClientResponse response = await httpRequest.close().timeout(
      const Duration(seconds: 120),
    );
    final String body = await utf8.decoder.bind(response).join();
    cancellation.throwIfCancelled();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('llama-server HTTP ${response.statusCode}: $body');
    }
    return jsonDecode(body);
  }

  Future<dynamic> _messageContent(
    String prompt,
    TranslationEngineRequest request,
    ModelDescriptor model,
  ) async {
    if (request.imagePath == null) {
      return prompt;
    }
    if (!model.supportsImages || model.imageProjectorArtifactId == null) {
      throw const EngineException(
        code: 'image_model_required',
        message: 'The selected GGUF has no verified image projector.',
        engineId: 'llama-server-translation',
      );
    }
    final File image = File(request.imagePath!);
    final List<int> bytes = await image.readAsBytes();
    return <Map<String, dynamic>>[
      <String, dynamic>{'type': 'text', 'text': prompt},
      <String, dynamic>{
        'type': 'image_url',
        'image_url': <String, String>{
          'url': 'data:${_mimeType(image.path)};base64,${base64Encode(bytes)}',
        },
      },
    ];
  }

  String? _contentFromResponse(dynamic data) {
    final dynamic choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return null;
    }
    final dynamic message = choices.first['message'];
    final dynamic content = message is Map ? message['content'] : null;
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      return content
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) => item['text'])
          .whereType<String>()
          .join('\n')
          .trim();
    }
    return null;
  }

  String? _resolveExecutable() {
    final String? managed = _runtimeStore.managedExecutablePathSync();
    if (managed != null) {
      return managed;
    }
    final String configured = _setting.localLlamaServerPath.value?.trim() ?? '';
    if (configured.isNotEmpty && File(configured).existsSync()) {
      return configured;
    }
    final String environment =
        Platform.environment['JH_LLAMA_SERVER']?.trim() ?? '';
    if (environment.isNotEmpty && File(environment).existsSync()) {
      return environment;
    }
    try {
      final ProcessResult result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        <String>['llama-server'],
      );
      if (result.exitCode == 0) {
        final String path = result.stdout.toString().trim().split('\n').first;
        if (path.isNotEmpty) {
          return path;
        }
      }
    } on Object {
      // No executable discovery is available on this platform/environment.
    }
    return null;
  }

  Future<int> _reservePort() async {
    final ServerSocket socket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final int port = socket.port;
    await socket.close();
    return port;
  }

  bool get _isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  String _mimeType(String path) {
    switch (path.toLowerCase().split('.').last) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }
}
