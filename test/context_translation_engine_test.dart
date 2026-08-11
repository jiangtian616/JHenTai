import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/api_translation_engine.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_registry.dart';
import 'package:jhentai/src/service/engine/local_translation_prompt.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';

ContextTranslationEngineRequest _request() {
  return const ContextTranslationEngineRequest(
    pages: <ContextTranslationPageRequest>[
      ContextTranslationPageRequest(
        pageId: 'page-10',
        pageHash: 'hash-10',
        lines: <ContextTranslationLineRequest>[
          ContextTranslationLineRequest(
            pageId: 'page-10',
            lineId: 'line-a',
            sourceText: 'first source',
          ),
        ],
      ),
      ContextTranslationPageRequest(
        pageId: 'page-11',
        pageHash: 'hash-11',
        lines: <ContextTranslationLineRequest>[
          ContextTranslationLineRequest(
            pageId: 'page-11',
            lineId: 'line-b',
            sourceText: 'second source',
          ),
        ],
      ),
    ],
    batchSize: ContextBatchSize.two,
    targetPageIds: <String>['page-10', 'page-11'],
    modelVersion: 'test-model',
    promptVersion: 1,
    targetLanguage: '简体中文',
    sourceLanguage: '日语',
    ocrConfiguration: <String, dynamic>{'engine': 'onnx'},
  );
}

void main() {
  test(
    'API context engine sends both pages once and parses stable IDs',
    () async {
      final ImageTranslationSetting setting = ImageTranslationSetting();
      setting.translatorProvider.value =
          ImageTranslationProvider.openAICompatible;
      setting.translatorEndpoint.value = 'https://translator.test/v1';
      setting.translatorApiKey.value = 'test-key';
      setting.translatorModel.value = 'test-model';
      int requestCount = 0;
      Map<String, dynamic>? postedData;
      final ApiTranslationEngine engine = ApiTranslationEngine(
        setting: setting,
        dioFactory: (BaseOptions options) {
          final Dio dio = Dio(options);
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requestCount++;
                postedData = Map<String, dynamic>.from(options.data as Map);
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'choices': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'message': <String, dynamic>{
                            'content': '''```json
{"translations":[{"pageId":"page-10","lineId":"line-a","text":"第一句"},{"pageId":"page-11","lineId":"line-b","text":"第二句"}]}
```''',
                          },
                        },
                      ],
                    },
                  ),
                );
              },
            ),
          );
          return dio;
        },
      );

      final ContextTranslationResult result =
          await engine.translateContext(_request()).future;

      expect(requestCount, 1);
      final List<dynamic> messages = postedData!['messages'] as List<dynamic>;
      final String prompt =
          (messages.last as Map<dynamic, dynamic>)['content'] as String;
      final Map<String, dynamic> payload =
          jsonDecode(prompt) as Map<String, dynamic>;
      expect(payload['targetPageIds'], <String>['page-10', 'page-11']);
      expect(payload['pages'], hasLength(2));
      expect(result.lines.map((line) => line.pageId), <String>[
        'page-10',
        'page-11',
      ]);
      expect(result.lines.map((line) => line.lineId), <String>[
        'line-a',
        'line-b',
      ]);
    },
  );

  test('local context prompt preserves page and line IDs and parses JSON', () {
    final LocalContextTranslationPrompt prompt =
        buildLocalContextTranslationPrompt(_request());
    final Map<String, dynamic> payload =
        jsonDecode(prompt.prompt) as Map<String, dynamic>;
    expect(payload['pages'], hasLength(2));
    expect(payload['targetPageIds'], <String>['page-10', 'page-11']);

    final ContextTranslationResult result =
        parseLocalContextTranslationResponse('''<think>hidden</think>
```json
{"translations":[{"pageId":"page-11","lineId":"line-b","text":"完成"}]}
```''');
    expect(result.lines.single.pageId, 'page-11');
    expect(result.lines.single.lineId, 'line-b');
    expect(result.lines.single.translatedText, '完成');
  });

  test('registry exposes context capability for API and local GGUF', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    final EngineRegistry registry = EngineRegistry(setting: setting);

    setting.translatorEngine.value = ImageTranslationEngine.api;
    expect(
      registry.selectedContextTranslation?.descriptor.id,
      'api-translation',
    );

    setting.translatorEngine.value = ImageTranslationEngine.localGguf;
    expect(registry.selectedContextTranslation, isNotNull);
    expect(
      registry.selectedContextTranslation?.descriptor.id,
      registry.selectedTranslation.descriptor.id,
    );
  });
}
