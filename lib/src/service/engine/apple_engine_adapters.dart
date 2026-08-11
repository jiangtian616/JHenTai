import 'dart:io';

import 'package:flutter/services.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

import 'engine_contract.dart';

const String liveTextOcrChannelName = 'top.jtmonster.jhentai.live_text_ocr';

class AppleLiveTextOcrEngine implements OcrEngine {
  AppleLiveTextOcrEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(liveTextOcrChannelName);

  final MethodChannel _channel;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'apple-live-text-ocr',
    kind: EngineKind.ocr,
    displayName: 'Apple Live Text',
    platforms: <EnginePlatform>{EnginePlatform.ios, EnginePlatform.macos},
  );

  @override
  bool get isReady => Platform.isIOS || Platform.isMacOS;

  @override
  EngineTask<OcrResult> recognize(
    OcrEngineRequest request,
  ) => EngineTask<OcrResult>.start(
    operation: (EngineTaskContext context) async {
      if (!isReady) {
        throw const EngineException(
          code: 'unsupported_platform',
          message: 'Apple Live Text OCR is available only on iOS/macOS.',
          engineId: 'apple-live-text-ocr',
        );
      }
      context.report(EngineTaskStage.processing, 0.1);
      final String languageSetting =
          request.configuration['language']?.toString() ?? 'auto';
      final List<String> languages =
          languageSetting.trim().isEmpty || languageSetting.trim() == 'auto'
              ? const <String>['ja-JP', 'zh-Hans', 'zh-Hant', 'ko-KR', 'en-US']
              : languageSetting
                  .split(',')
                  .map((String language) => language.trim())
                  .where((String language) => language.isNotEmpty)
                  .toList(growable: false);
      try {
        final Map<dynamic, dynamic>? response = await _channel.invokeMethod<
          Map<dynamic, dynamic>
        >('recognizeText', <String, dynamic>{
          'path': request.imagePath,
          'languages': languages,
          'automaticallyDetectsLanguage': false,
          'recognitionLevel': 'accurate',
          'maxDimension': request.maxDimension,
        });
        context.cancellation.throwIfCancelled();
        if (response == null) {
          throw const EngineException(
            code: 'recognition_failed',
            message: 'Apple Vision returned no response.',
            engineId: 'apple-live-text-ocr',
          );
        }
        final List<RecognizedTextBlock> blocks =
            (response['lines'] as List?)
                ?.whereType<Map>()
                .map(_blockFromJson)
                .where(
                  (RecognizedTextBlock block) => block.text.trim().isNotEmpty,
                )
                .toList(growable: false) ??
            const <RecognizedTextBlock>[];
        if (blocks.isEmpty) {
          throw const EngineException(
            code: 'no_text',
            message: 'Apple Vision recognized no text.',
            engineId: 'apple-live-text-ocr',
          );
        }
        context.report(EngineTaskStage.finalizing, 0.98);
        return OcrResult(
          blocks: blocks,
          imageWidth: (response['width'] as num?)?.toInt(),
          imageHeight: (response['height'] as num?)?.toInt(),
        );
      } on PlatformException catch (error) {
        throw EngineException(
          code:
              error.code == 'OCR_FAILED'
                  ? 'recognition_failed'
                  : error.code.toLowerCase(),
          message: error.message ?? error.code,
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );

  RecognizedTextBlock _blockFromJson(Map<dynamic, dynamic> raw) =>
      RecognizedTextBlock(
        text: raw['text'] as String? ?? '',
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
        left: (raw['left'] as num?)?.toDouble() ?? 0,
        top: (raw['top'] as num?)?.toDouble() ?? 0,
        width: (raw['width'] as num?)?.toDouble() ?? 0,
        height: (raw['height'] as num?)?.toDouble() ?? 0,
      );
}

class AppleTranslationEngine implements TranslationEngine {
  AppleTranslationEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(liveTextOcrChannelName);

  final MethodChannel _channel;

  @override
  final EngineDescriptor descriptor = const EngineDescriptor(
    id: 'apple-translation',
    kind: EngineKind.translation,
    displayName: 'Apple On-Device Translation',
    platforms: <EnginePlatform>{EnginePlatform.ios, EnginePlatform.macos},
  );

  @override
  bool get isReady => Platform.isIOS || Platform.isMacOS;

  @override
  EngineTask<TranslationResult> translate(
    TranslationEngineRequest request,
  ) => EngineTask<TranslationResult>.start(
    operation: (EngineTaskContext context) async {
      if (!isReady) {
        throw const EngineException(
          code: 'unsupported_platform',
          message: 'Apple Translation is available only on iOS/macOS.',
          engineId: 'apple-translation',
        );
      }
      final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(
        request.blocks,
      );
      final List<String> groupSources = groups
          .map((RecognizedTextGroup group) => group.textOf(request.blocks))
          .toList(growable: false);
      context.report(EngineTaskStage.processing, 0.1);
      try {
        final Map<dynamic, dynamic>? response = await _channel.invokeMethod<
          Map<dynamic, dynamic>
        >('translateText', <String, dynamic>{
          'lines': groupSources,
          'target': request.targetLanguage,
          'source': request.sourceLanguage,
        });
        context.cancellation.throwIfCancelled();
        final List<String> translatedGroups =
            (response?['lines'] as List?)
                ?.map((Object? line) => line?.toString() ?? '')
                .toList(growable: false) ??
            const <String>[];
        if (translatedGroups.isEmpty) {
          throw const EngineException(
            code: 'translation_failed',
            message: 'Apple Translation returned no lines.',
            engineId: 'apple-translation',
          );
        }
        final List<String> lines = <String>[];
        for (int index = 0; index < groups.length; index++) {
          final String translation =
              index < translatedGroups.length ? translatedGroups[index] : '';
          final List<String> sourceLines = groups[index].blockIndices
              .map((int blockIndex) => request.blocks[blockIndex].text.trim())
              .toList(growable: false);
          lines.addAll(
            splitGroupTranslationIntoLines(
              translation:
                  translation.isEmpty ? groupSources[index] : translation,
              sourceLines: sourceLines,
            ),
          );
        }
        context.report(EngineTaskStage.finalizing, 0.98);
        return TranslationResult(
          translatedText: lines.join('\n'),
          lines: lines,
        );
      } on PlatformException catch (error) {
        final String code = switch (error.code) {
          'TRANSLATION_UNAVAILABLE' => 'translation_unavailable',
          'TRANSLATION_NOT_INSTALLED' => 'translation_not_installed',
          _ => 'translation_failed',
        };
        throw EngineException(
          code: code,
          message: error.message ?? error.code,
          engineId: descriptor.id,
          cause: error,
        );
      }
    },
  );
}
