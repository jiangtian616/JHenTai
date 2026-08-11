import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/ocr_layout_protocol.dart';

/// Conservative Japanese vertical-text suggestion policy. It never changes a
/// user's engine selection; callers may use it to offer a manual suggestion or
/// to try manga-OCR only when that adapter is actually ready.
class MangaOcrLanguageAdvisor {
  const MangaOcrLanguageAdvisor._();

  static final RegExp japaneseScript = RegExp(r'[ぁ-ゟ゠-ヿ]');

  static bool containsJapanese(Iterable<RecognizedTextBlock> blocks) => blocks
      .any((RecognizedTextBlock block) => japaneseScript.hasMatch(block.text));

  static bool isVertical(Iterable<RecognizedTextBlock> blocks) {
    final List<OcrLayoutBox> boxes = <OcrLayoutBox>[
      for (int i = 0; i < blocks.length; i++)
        OcrLayoutBox(
          sourceIndex: i,
          left: blocks.elementAt(i).left,
          top: blocks.elementAt(i).top,
          width: blocks.elementAt(i).width,
          height: blocks.elementAt(i).height,
        ),
    ];
    return classifyOcrLayout(boxes) == OcrLayoutMode.verticalRtl;
  }

  static bool shouldSuggest(Iterable<RecognizedTextBlock> blocks) {
    final List<RecognizedTextBlock> values = blocks.toList(growable: false);
    return values.isNotEmpty && containsJapanese(values) && isVertical(values);
  }
}
