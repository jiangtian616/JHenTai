import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

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

LocalTranslationPrompt buildLocalTranslationPrompt(
  List<RecognizedTextBlock> blocks,
  String targetLanguage,
) {
  final List<String> sourceLines = blocks
      .map((RecognizedTextBlock block) => block.text.trim())
      .toList(growable: false);
  final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(blocks);
  final StringBuffer numberedSource = StringBuffer();
  for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    numberedSource.writeln('Group ${groupIndex + 1}:');
    for (final int blockIndex in groups[groupIndex].blockIndices) {
      numberedSource.writeln('${blockIndex + 1}: ${sourceLines[blockIndex]}');
    }
  }
  const String instruction =
      'You translate comic dialogue accurately. The input lines are grouped into numbered groups; each group is one '
      'speech bubble or utterance. Translate each group as a single coherent utterance, combining its line fragments '
      'into natural phrasing. Preserve line order and line count within each group. '
      'Return exactly one translated line per input line, numbered the same as the input (e.g. "1: ..."). '
      'Use continuous numbering across all groups — do not restart the numbers per group. '
      'Do not add headings, group labels, numbering, or reasoning/think blocks.';
  return LocalTranslationPrompt(
    instruction: instruction,
    prompt:
        'Translate the following comic text into $targetLanguage. Keep the same line numbers:\n\n$numberedSource',
    sourceLines: sourceLines,
  );
}

List<String> parseLocalNumberedTranslations(String text, int lineCount) {
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
