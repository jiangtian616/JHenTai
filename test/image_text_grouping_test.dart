import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';

RecognizedTextBlock _block({
  required double top,
  required double left,
  required double width,
  required double height,
  String text = '',
}) => RecognizedTextBlock(
  text: text,
  confidence: 1,
  left: left,
  top: top,
  width: width,
  height: height,
);

void main() {
  group('groupRecognizedTextBlocks', () {
    test('merges stacked lines of one bubble into a single group', () {
      // Two lines in one bubble, tightly stacked and horizontally overlapping.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 200, width: 200, height: 30, text: 'line 1'),
        _block(top: 138, left: 210, width: 180, height: 30, text: 'line 2'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(1));
      expect(groups.single.blockIndices, equals(<int>[0, 1]));
    });

    test('keeps two vertically stacked bubbles separate', () {
      // Bubble A lines at top 100/140; bubble B well below at top 400.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 200, width: 200, height: 30, text: 'A1'),
        _block(top: 138, left: 210, width: 180, height: 30, text: 'A2'),
        _block(top: 400, left: 300, width: 150, height: 28, text: 'B1'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(2));
      expect(groups[0].blockIndices, equals(<int>[0, 1]));
      expect(groups[1].blockIndices, equals(<int>[2]));
    });

    test('keeps interleaved side-by-side bubbles separate', () {
      // Two bubbles side by side spanning the same vertical band: the
      // top-then-left reading order interleaves them. Horizontal distance must
      // prevent cross-bubble merges.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 100, width: 180, height: 30, text: 'A1'),
        _block(top: 105, left: 500, width: 180, height: 30, text: 'B1'),
        _block(top: 140, left: 110, width: 170, height: 30, text: 'A2'),
        _block(top: 145, left: 510, width: 170, height: 30, text: 'B2'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(2));
      expect(groups[0].blockIndices, equals(<int>[0, 2]));
      expect(groups[1].blockIndices, equals(<int>[1, 3]));
    });

    test('does not merge lines on the same row', () {
      // The detector split one visual line into two boxes; they overlap
      // vertically so must not be treated as a stacked utterance.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 100, width: 90, height: 30, text: 'part'),
        _block(top: 108, left: 200, width: 90, height: 30, text: 'two'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(2));
    });

    test('merges a short line centered under a long line', () {
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 150, width: 300, height: 30, text: 'long line'),
        // Narrow line, centered under the long one, small overlap ratio.
        _block(top: 136, left: 225, width: 150, height: 30, text: 'short'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(1));
    });

    test('merges stacked lines whose inflated boxes overlap ~40%', () {
      // The ONNX detector inflates boxes (its `expand` adds ~10-15px/side), so
      // two stacked lines of one bubble can overlap vertically by ~40% of the
      // shorter box. This must still merge as one utterance.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 200, width: 200, height: 40, text: 'line 1'),
        // bottom of line1 = 140; line2 top = 118 -> vertical overlap 22/40.
        _block(top: 118, left: 205, width: 190, height: 40, text: 'line 2'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(1));
    });

    test('gives geometry-less blocks their own group without merging', () {
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 200, width: 200, height: 30, text: 'with box'),
        _block(top: 0, left: 0, width: 0, height: 0, text: 'no box'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(2));
    });

    test('computes the combined bounding box of a group', () {
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 200, width: 200, height: 30, text: 'a'),
        _block(top: 136, left: 180, width: 240, height: 30, text: 'b'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups.single.left, 180);
      expect(groups.single.top, 100);
      expect(groups.single.right, 420);
      expect(groups.single.bottom, 166);
    });

    test('groups side-by-side columns of a vertical-text bubble', () {
      // Tategaki: three tall columns of one bubble, read right-to-left.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 500, width: 30, height: 200, text: 'col1'),
        _block(top: 105, left: 460, width: 28, height: 190, text: 'col2'),
        _block(top: 100, left: 420, width: 30, height: 200, text: 'col3'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(1));
      expect(groups.single.blockIndices, equals(<int>[0, 1, 2]));
    });

    test('keeps vertically stacked bubbles on a vertical page separate', () {
      // Two separate bubbles, each a single column, one above the other: no
      // vertical overlap, so they must not merge.
      final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
        _block(top: 100, left: 500, width: 30, height: 200, text: 'A'),
        _block(top: 420, left: 470, width: 30, height: 180, text: 'B'),
      ];
      final List<RecognizedTextGroup> groups =
          groupRecognizedTextBlocks(blocks);
      expect(groups, hasLength(2));
    });
  });

  group('splitGroupTranslationIntoLines', () {
    test('keeps a single-line group as-is', () {
      expect(
        splitGroupTranslationIntoLines(
          translation: '我今天去学校了。',
          sourceLines: <String>['学校に行きました'],
        ),
        equals(<String>['我今天去学校了。']),
      );
    });

    test('uses preserved line breaks when they match the line count', () {
      expect(
        splitGroupTranslationIntoLines(
          translation: '我今天\n去学校了',
          sourceLines: <String>['私は今日', '学校に行きました'],
        ),
        equals(<String>['我今天', '去学校了']),
      );
    });

    test('splits a collapsed translation proportionally to source length', () {
      // Source weights 5 / 7 -> translated 8 chars -> ~3 / 5.
      final List<String> result = splitGroupTranslationIntoLines(
        translation: '我今天去学校了。',
        sourceLines: <String>['私は今日は', '学校に行きました'],
      );
      expect(result, hasLength(2));
      expect(result[0] + result[1], '我今天去学校了。');
    });

    test('prefers a punctuation boundary when splitting', () {
      final List<String> result = splitGroupTranslationIntoLines(
        translation: '好累啊！一起去学校吧。',
        sourceLines: <String>['つかれた', 'いっしょにがっこういこう'],
      );
      expect(result, hasLength(2));
      // The cut should land at or near "！" rather than mid-phrase.
      expect(result[0], contains('！'));
    });

    test('returns empty lines when the translation is empty', () {
      final List<String> result = splitGroupTranslationIntoLines(
        translation: '   ',
        sourceLines: <String>['a', 'b'],
      );
      expect(result, equals(<String>['', '']));
    });
  });
}
