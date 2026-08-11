import 'dart:async';

import 'package:dio/dio.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

import 'engine_contract.dart';

class ApiTranslationEngine implements TranslationEngine {
  ApiTranslationEngine({ImageTranslationSetting? setting})
    : _setting = setting ?? imageTranslationSetting;

  final ImageTranslationSetting _setting;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'api-translation',
    kind: EngineKind.translation,
    displayName: 'Configured Translation API',
    platforms: <EnginePlatform>{
      EnginePlatform.android,
      EnginePlatform.ios,
      EnginePlatform.linux,
      EnginePlatform.macos,
      EnginePlatform.windows,
      EnginePlatform.web,
    },
  );

  @override
  bool get isReady => _setting.isTranslatorConfigured;

  @override
  EngineTask<TranslationResult> translate(
    TranslationEngineRequest request,
  ) => EngineTask<TranslationResult>.start(
    operation: (EngineTaskContext context) async {
      if (!isReady) {
        throw const EngineException(
          code: 'not_configured',
          message: 'A translation API endpoint, key and model are required.',
          engineId: 'api-translation',
        );
      }
      final List<String> sourceLines = request.blocks
          .map((RecognizedTextBlock block) => block.text.trim())
          .toList(growable: false);
      final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(
        request.blocks,
      );
      final StringBuffer numberedSource = StringBuffer();
      for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
        numberedSource.writeln('Group ${groupIndex + 1}:');
        for (final int blockIndex in groups[groupIndex].blockIndices) {
          numberedSource.writeln(
            '${blockIndex + 1}: ${sourceLines[blockIndex]}',
          );
        }
      }
      final String instruction =
          'You translate comic dialogue accurately. The input lines are grouped into numbered groups; each group is one '
          'speech bubble or utterance. Translate each group as a single coherent utterance, combining its line fragments '
          'into natural phrasing. Preserve line order and line count within each group. '
          'Return exactly one translated line per input line, numbered the same as the input (e.g. "1: ..."). '
          'Use continuous numbering across all groups — do not restart the numbers per group. '
          'Do not add headings, group labels, numbering, or reasoning/think blocks.';
      final String prompt =
          'Translate the following comic text into ${request.targetLanguage}. Keep the same line numbers:\n\n$numberedSource';
      final Dio dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final CancelToken cancelToken = CancelToken();
      final subscription = context.cancellation.onCancel.listen(
        (_) => cancelToken.cancel('engine task cancelled'),
      );
      context.report(EngineTaskStage.processing, 0.1);
      try {
        final String endpoint = _translationEndpoint(
          _setting.translatorEndpoint.value!,
          _setting.translatorProvider.value,
        );
        final Response<dynamic> response;
        if (_setting.translatorProvider.value ==
            ImageTranslationProvider.anthropic) {
          response = await dio.post(
            endpoint,
            options: Options(
              headers: _anthropicHeaders(_setting.translatorApiKey.value!),
            ),
            cancelToken: cancelToken,
            data: <String, dynamic>{
              'model': _setting.translatorModel.value,
              'max_tokens': 2048,
              'system': instruction,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'user', 'content': prompt},
              ],
              ...?_thinkingParam(),
            },
          );
        } else {
          response = await dio.post(
            endpoint,
            options: Options(
              headers: _openAIHeaders(_setting.translatorApiKey.value!),
            ),
            cancelToken: cancelToken,
            data: <String, dynamic>{
              'model': _setting.translatorModel.value,
              'temperature': 0.2,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'system', 'content': instruction},
                <String, String>{'role': 'user', 'content': prompt},
              ],
              ...?_thinkingParam(),
            },
          );
        }
        final String? content = _contentFromResponse(response.data);
        if (content == null || content.trim().isEmpty) {
          throw const EngineException(
            code: 'invalid_response',
            message: 'The translation API returned no text.',
            engineId: 'api-translation',
          );
        }
        final List<String> lines = _parseNumberedTranslations(
          _stripReasoning(content),
          sourceLines.length,
        );
        context.report(EngineTaskStage.finalizing, 0.98);
        return TranslationResult(
          translatedText: lines.join('\n'),
          lines: lines,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) || context.cancellation.isCancelled) {
          throw EngineTaskCancelledException(context.cancellation.reason);
        }
        throw EngineException(
          code: 'request_failed',
          message: error.message ?? error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      } on TimeoutException catch (error) {
        throw EngineException(
          code: 'timeout',
          message: error.toString(),
          engineId: descriptor.id,
          cause: error,
        );
      } finally {
        await subscription.cancel();
      }
    },
  );

  Future<List<String>> fetchModels({
    required ImageTranslationProvider provider,
    required String apiBaseUrl,
    required String apiKey,
  }) async {
    final String baseUrl = _trimUrl(apiBaseUrl);
    if (baseUrl.isEmpty || apiKey.trim().isEmpty) {
      throw const EngineException(
        code: 'configuration_required',
        message: 'API base URL and key are required.',
        engineId: 'api-translation',
      );
    }
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final Response<dynamic> response = await dio.get(
      _modelsEndpoint(baseUrl),
      options: Options(
        headers:
            provider == ImageTranslationProvider.anthropic
                ? _anthropicHeaders(apiKey)
                : _openAIHeaders(apiKey),
      ),
    );
    final dynamic models = response.data is Map ? response.data['data'] : null;
    if (models is! List) {
      throw const EngineException(
        code: 'invalid_response',
        message: 'The model list response is invalid.',
        engineId: 'api-translation',
      );
    }
    final List<String> ids =
        models
            .whereType<Map>()
            .map((Map<dynamic, dynamic> model) => model['id'])
            .whereType<String>()
            .where((String id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (ids.isEmpty) {
      throw const EngineException(
        code: 'empty_models',
        message: 'The model list is empty.',
        engineId: 'api-translation',
      );
    }
    return ids;
  }

  String? _contentFromResponse(dynamic data) {
    if (_setting.translatorProvider.value ==
        ImageTranslationProvider.anthropic) {
      final dynamic blocks = data is Map ? data['content'] : null;
      return blocks is List
          ? blocks
              .whereType<Map>()
              .map((Map<dynamic, dynamic> block) => block['text'])
              .whereType<String>()
              .join('\n')
              .trim()
          : null;
    }
    final dynamic choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty || choices.first is! Map)
      return null;
    final dynamic message = choices.first['message'];
    final dynamic content = message is Map ? message['content'] : null;
    return content is String ? content.trim() : null;
  }

  List<String> _parseNumberedTranslations(String text, int lineCount) {
    final List<String?> result = List<String?>.filled(lineCount, null);
    int fallbackIndex = 0;
    for (final String rawLine in text.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty ||
          RegExp(r'^\s*group\s*\d+', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      final RegExpMatch? match = RegExp(
        r'^\s*(\d+)\s*[:：.]?\s*(.*)$',
      ).firstMatch(line);
      final int? index = match == null ? null : int.tryParse(match.group(1)!);
      if (index != null && index >= 1 && index <= lineCount) {
        result[index - 1] = match!.group(2)!.trim();
        continue;
      }
      while (fallbackIndex < lineCount && result[fallbackIndex] != null) {
        fallbackIndex++;
      }
      if (fallbackIndex < lineCount) result[fallbackIndex++] = line;
    }
    return result.map((String? line) => line ?? '').toList(growable: false);
  }

  String _stripReasoning(String text) =>
      text
          .replaceAllMapped(
            RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
            (_) => '',
          )
          .replaceAllMapped(
            RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
            (_) => '',
          )
          .replaceAllMapped(
            RegExp(r'\[/?reasoning\]', caseSensitive: false),
            (_) => '',
          )
          .replaceAll(RegExp(r'\n\s*\n+'), '\n')
          .trim();

  Map<String, dynamic>? _thinkingParam() {
    final String model = _setting.translatorModel.value.toLowerCase();
    if (!model.contains('minimax') && !model.contains('m3')) return null;
    return <String, dynamic>{
      'thinking': <String, String>{
        'type': _setting.enableThinking.value ? 'adaptive' : 'disabled',
      },
    };
  }

  String _modelsEndpoint(String baseUrl) => '${_trimUrl(baseUrl)}/models';

  String _translationEndpoint(
    String baseUrl,
    ImageTranslationProvider provider,
  ) =>
      '${_trimUrl(baseUrl)}/${provider == ImageTranslationProvider.anthropic ? 'messages' : 'chat/completions'}';

  String _trimUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  Map<String, String> _openAIHeaders(String apiKey) => <String, String>{
    'Authorization': 'Bearer ${apiKey.trim()}',
    'Content-Type': 'application/json',
  };

  Map<String, String> _anthropicHeaders(String apiKey) => <String, String>{
    'x-api-key': apiKey.trim(),
    'anthropic-version': '2023-06-01',
    'Content-Type': 'application/json',
  };
}
