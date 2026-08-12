import 'dart:convert';

import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

import 'context_translation_contract.dart';

class LocalTranslationPrompt {
  const LocalTranslationPrompt({
    required this.instruction,
    required this.prompt,
    required this.sourceLines,
  });

  final String instruction;
  final String prompt;
  final List<String> sourceLines;
}

class LocalContextTranslationPrompt {
  const LocalContextTranslationPrompt({
    required this.instruction,
    required this.prompt,
  });

  final String instruction;
  final String prompt;
}

LocalContextTranslationPrompt buildLocalContextTranslationPrompt(
  ContextTranslationEngineRequest request,
) {
  const String instruction =
      'Translate comic dialogue using neighboring pages as context. '
      'Return only one JSON object with a translations array. Every item must contain the exact input pageId and lineId plus translated text. '
      'Return items only for targetPageIds, preserve every target line exactly once, and never add markdown, commentary, or reasoning.';
  return LocalContextTranslationPrompt(
    instruction: instruction,
    prompt: jsonEncode(<String, dynamic>{
      'targetLanguage': request.targetLanguage,
      'sourceLanguage': request.sourceLanguage,
      'targetPageIds': request.targetPageIds,
      'pages': request.pages
          .map((ContextTranslationPageRequest page) => page.toJson())
          .toList(growable: false),
      'responseSchema': <String, dynamic>{
        'translations': <Map<String, String>>[
          <String, String>{
            'pageId': 'exact input pageId',
            'lineId': 'exact input lineId',
            'text': 'translated text',
          },
        ],
      },
    }),
  );
}

ContextTranslationResult parseLocalContextTranslationResponse(dynamic value) {
  if (value is Map && value['translations'] is List) {
    return ContextTranslationResult.fromJson(value);
  }
  final String? text =
      value is String
          ? value
          : value is Map
          ? (value['translatedText'] ?? value['text'])?.toString()
          : null;
  if (text == null || text.trim().isEmpty) {
    throw const FormatException(
      'The local translation runtime returned no context translation.',
    );
  }
  final String cleaned =
      stripLocalReasoning(text)
          .replaceFirst(
            RegExp(r'^\s*```(?:json)?\s*', caseSensitive: false),
            '',
          )
          .replaceFirst(RegExp(r'\s*```\s*$'), '')
          .trim();
  final int start = cleaned.indexOf('{');
  final int end = cleaned.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const FormatException(
      'The local context translation did not contain a JSON object.',
    );
  }
  return ContextTranslationResult.fromJson(
    jsonDecode(cleaned.substring(start, end + 1)),
  );
}

LocalTranslationPrompt buildLocalTranslationPrompt(
  List<RecognizedTextBlock> blocks,
  String targetLanguage, {
  bool mergeTextBlocks = true,
  List<RecognizedTextContainer> containers = const <RecognizedTextContainer>[],
}) {
  final List<String> sourceLines = blocks
      .map((RecognizedTextBlock block) => block.text.trim())
      .toList(growable: false);
  final List<RecognizedTextGroup> groups = translationTextGroups(
    blocks,
    merge: mergeTextBlocks,
    containers: containers,
  );
  final String numberedSource = buildGroupedTranslationSource(blocks, groups);
  const String instruction =
      'You translate comic dialogue accurately. Each numbered group is one speech bubble or utterance. '
      'Translate the whole group as one natural, context-aware utterance. Keep names, tone, hesitation, '
      'sound effects and profanity faithful to the source. Return exactly one translated line per group, '
      'using the same group number (for example "1: ..."). Do not split a group into extra lines, '
      'add headings or commentary, or include reasoning/think blocks.';
  return LocalTranslationPrompt(
    instruction: instruction,
    prompt:
        'Translate the following comic text into $targetLanguage. Keep the same group numbers:\n\n$numberedSource',
    sourceLines: sourceLines,
  );
}

List<String> parseLocalNumberedTranslations(String text, int lineCount) {
  return parseNumberedTranslations(text, lineCount);
}

String stripLocalReasoning(String text) =>
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
