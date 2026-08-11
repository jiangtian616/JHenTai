import 'dart:convert';
import 'dart:math' as math;

import '../model/image_translation.dart';
import 'ocr_layout_protocol.dart';

/// A cluster of recognized text lines that together form one utterance —
/// typically the lines inside a single speech bubble or caption box. Built by
/// [groupRecognizedTextBlocks] so translation can treat a multi-line utterance
/// as a coherent whole instead of translating each line in isolation (which
/// produces fragmentary, out-of-context translations for manga bubbles).
class RecognizedTextGroup {
  const RecognizedTextGroup({
    required this.blockIndices,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Indices into the source [RecognizedTextBlock] list, in reading order.
  final List<int> blockIndices;

  /// Combined bounding box (top-left origin, upright image pixel space).
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// The member blocks in reading order.
  List<RecognizedTextBlock> blocksOf(List<RecognizedTextBlock> all) => [
    for (final int index in blockIndices) all[index],
  ];

  /// The group's text with its lines joined by newlines — the unit a
  /// translator should translate as one utterance.
  String textOf(List<RecognizedTextBlock> all) =>
      blockIndices.map((int index) => all[index].text.trim()).join('\n');
}

/// Punctuation characters that make a natural end for a bubble line, used when
/// re-splitting a group's translation back into its original line count.
const String _lineBreakPunctuation = '。！？!?．.、，,…⋯';

/// Characters that naturally follow a cut (closing quotes/brackets); a cut
/// after one of these keeps the closer attached to the preceding line.
const String _cutAfterPunctuation = '。！？!?．.、，,…⋯」』）)」』」『』';

/// Splits one group's translated text back into `sourceLines.length` lines so
/// the overlay keeps a 1:1 mapping between recognized blocks and translated
/// text.
///
/// Apple's on-device translation does not reliably preserve the newlines of
/// multi-line input (soft line breaks tend to collapse to spaces), so the
/// group's translated output is re-split here. Prefers preserved line breaks
/// when they already match the line count; otherwise splits at punctuation
/// boundaries proportionally to the source lines' lengths, which fits CJK→CJK
/// manga bubbles well.
List<String> splitGroupTranslationIntoLines({
  required String translation,
  required List<String> sourceLines,
}) {
  final int lineCount = sourceLines.length;
  if (lineCount <= 1) {
    return <String>[translation.trim()];
  }
  // Fast path: the translator happened to preserve the line breaks.
  final List<String> byNewline = const LineSplitter()
      .convert(translation)
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
  if (byNewline.length == lineCount) {
    return byNewline;
  }
  final String text = translation.trim();
  final List<String> result = List<String>.filled(lineCount, '');
  if (text.isEmpty) {
    return result;
  }
  // Weight each target line by its source length, so a long source line
  // receives a proportionally long share of the translated text.
  final List<int> weights = sourceLines
      .map((String line) => math.max(1, line.trim().length))
      .toList();
  final int totalWeight = weights.fold<int>(
    0,
    (int sum, int weight) => sum + weight,
  );
  final List<int> cuts = <int>[];
  int accumulated = 0;
  for (int i = 0; i < lineCount - 1; i++) {
    accumulated += weights[i];
    final int ideal = (text.length * accumulated / totalWeight).round().clamp(
      1,
      text.length - 1,
    );
    cuts.add(_nearestLineBreak(text, ideal));
  }
  int start = 0;
  for (int i = 0; i < lineCount; i++) {
    final int end = i < cuts.length ? cuts[i] : text.length;
    result[i] = text.substring(start, end).trim();
    start = end;
  }
  return result;
}

/// Snaps [index] to the nearest character that makes a natural line end,
/// within a couple of characters on either side, so a bubble line does not cut
/// mid-word when a punctuation mark is right there.
int _nearestLineBreak(String text, int index) {
  for (int offset = 0; offset <= 2; offset++) {
    for (final int direction in const <int>[1, -1]) {
      final int candidate = index + direction * offset;
      if (candidate > 0 && candidate < text.length) {
        final String char = text[candidate];
        // A cut after a closing punctuation mark keeps it with the preceding
        // line; a cut at an opening/connecting mark keeps it with the next.
        if (_cutAfterPunctuation.contains(char)) {
          return candidate + 1;
        }
        if (_lineBreakPunctuation.contains(char)) {
          return candidate;
        }
      }
    }
  }
  return index;
}

/// Maximum vertical gap between consecutive lines (as a multiple of the
/// smaller line's height) that still counts as "inside one bubble". Manga line
/// spacing is typically 0.1-0.5x the line height; the white margin between
/// bubbles is usually much larger, so 1.4x separates them.
const double _maxLineGapRatio = 1.4;

/// Maximum horizontal gap between adjacent vertical-text columns (as a
/// multiple of the narrower column) that still counts as "inside one bubble".
/// Mirrors [_maxLineGapRatio] for tategaki (vertical Japanese) text.
const double _maxColumnGapRatio = 1.4;

/// Minimum horizontal overlap of two lines' x-ranges (as a fraction of the
/// narrower line) required to merge. Keeps same-band side-by-side bubbles from
/// merging even when the reading order interleaves their lines.
const double _minOverlapRatio = 0.25;

/// If the x-ranges barely overlap (e.g. a short line centered under a long
/// one), the lines may still be one utterance when their centers align.
const double _maxCenterOffsetRatio = 0.4;

/// When two boxes overlap vertically by more than this fraction of the shorter
/// box they are treated as fragments of the SAME visual row, not as stacked
/// lines of one utterance. The tolerance must be generous: the ONNX detector
/// inflates every box (its `expand` adds roughly 10-15px per side), so two
/// genuinely stacked lines of one bubble routinely overlap by ~40% of the
/// shorter box. A threshold at 0.6 separates those (≤~0.5) from true
/// same-row fragments of a split line (≥~0.8).
const double _maxVerticalOverlapRatio = 0.6;

/// Clusters reading-order-sorted [RecognizedTextBlock]s into utterance groups.
///
/// OCR engines report one block per visual text line, so a single manga speech
/// bubble that spans several lines arrives as several adjacent blocks. This
/// clusters blocks that sit close together vertically AND overlap horizontally
/// (the signature of stacked lines inside one bubble), while keeping blocks
/// from distinct bubbles separate.
///
/// Blocks are processed in reading order but several groups stay "open" at
/// once, so two bubbles side by side whose lines interleave in the
/// top-then-left sort still end up as two groups (each line joins the bubble
/// that is horizontally close to it), rather than a consecutive-window scan
/// which would see A1,B1,A2,B2 and group them wrongly.
///
/// Blocks without usable geometry (e.g. some Paddle outputs that carry text but
/// no box) cannot be placed spatially and always form their own group, so they
/// still translate but never merge neighbors.
List<RecognizedTextGroup> groupRecognizedTextBlocks(
  List<RecognizedTextBlock> blocks,
) {
  if (blocks.isEmpty) {
    return const [];
  }

  // Tategaki (vertical Japanese) pages have tall, narrow columns of text read
  // right-to-left instead of stacked horizontal lines. Grouping uses a
  // different proximity rule for those pages (side-by-side columns instead of
  // stacked lines), so pick the dominant orientation up front — the same
  // heuristic the ONNX detector uses to choose its reading order.
  final bool mostlyVertical = _isMostlyVertical(blocks);

  final List<List<int>> groupIndices = <List<int>>[];
  final List<double> groupLeft = <double>[];
  final List<double> groupTop = <double>[];
  final List<double> groupRight = <double>[];
  final List<double> groupBottom = <double>[];
  // Geometry of the most recently added member per group; null for groups that
  // can no longer accept lines (their last member has no box).
  final List<RecognizedTextBlock?> groupLast = <RecognizedTextBlock?>[];

  void addToGroup(int group, int blockIndex, RecognizedTextBlock block) {
    groupIndices[group].add(blockIndex);
    groupLeft[group] = math.min(groupLeft[group], block.left);
    groupTop[group] = math.min(groupTop[group], block.top);
    groupRight[group] = math.max(groupRight[group], block.left + block.width);
    groupBottom[group] = math.max(groupBottom[group], block.top + block.height);
    groupLast[group] = block;
  }

  void startGroup(int blockIndex, RecognizedTextBlock block) {
    groupIndices.add(<int>[blockIndex]);
    groupLeft.add(block.left);
    groupTop.add(block.top);
    groupRight.add(block.left + block.width);
    groupBottom.add(block.top + block.height);
    groupLast.add(block);
  }

  for (int index = 0; index < blocks.length; index++) {
    final RecognizedTextBlock block = blocks[index];
    if (block.width <= 0 || block.height <= 0) {
      // No usable geometry: its own group, never merged.
      startGroup(index, block);
      continue;
    }

    int? bestGroup;
    double bestScore = 0;
    for (int group = 0; group < groupIndices.length; group++) {
      final RecognizedTextBlock? last = groupLast[group];
      if (last == null || last.width <= 0 || last.height <= 0) {
        continue;
      }
      final double? score = mostlyVertical
          ? _verticalGroupMatchScore(last, block)
          : _horizontalGroupMatchScore(last, block);
      if (score != null && score > bestScore) {
        bestScore = score;
        bestGroup = group;
      }
    }

    if (bestGroup != null) {
      addToGroup(bestGroup, index, block);
    } else {
      startGroup(index, block);
    }
  }

  return List<RecognizedTextGroup>.generate(
    groupIndices.length,
    (int group) => RecognizedTextGroup(
      blockIndices: groupIndices[group],
      left: groupLeft[group],
      top: groupTop[group],
      right: groupRight[group],
      bottom: groupBottom[group],
    ),
  );
}

/// Whether the page is dominated by tall, narrow blocks — the signature of
/// tategaki (vertical Japanese) text columns. Uses the same threshold the ONNX
/// detector applies when choosing its right-to-left reading order.
bool _isMostlyVertical(List<RecognizedTextBlock> blocks) {
  int total = 0;
  int vertical = 0;
  for (final RecognizedTextBlock block in blocks) {
    if (block.width <= 0 || block.height <= 0) {
      continue;
    }
    total++;
    if (block.height > block.width * OcrScoringProtocol.verticalAspectRatio) {
      vertical++;
    }
  }
  return total > 0 && vertical * 2 > total;
}

/// Returns a non-null merge score when [candidate] should join a group whose
/// most recent member is [last], or null when they must stay separate. Higher
/// score = stronger match, so when a line could plausibly join several open
/// groups the best one wins.
double? _horizontalGroupMatchScore(
  RecognizedTextBlock last,
  RecognizedTextBlock candidate,
) {
  final double lastBottom = last.top + last.height;
  final double candidateBottom = candidate.top + candidate.height;

  // Same visual row (boxes overlap vertically by a large fraction): the
  // detector split one line into pieces, not a stacked utterance.
  final double verticalOverlap =
      math.min(lastBottom, candidateBottom) - math.max(last.top, candidate.top);
  if (verticalOverlap >
      _maxVerticalOverlapRatio * math.min(last.height, candidate.height)) {
    return null;
  }

  // Vertically close enough to be stacked lines of one bubble.
  final double gap = candidate.top - lastBottom;
  final double maxGap =
      _maxLineGapRatio * math.min(last.height, candidate.height);
  if (gap > maxGap) {
    return null;
  }

  // Horizontally close: overlapping x-ranges, or centered under each other.
  final double lastLeft = last.left;
  final double lastRight = last.left + last.width;
  final double candidateLeft = candidate.left;
  final double candidateRight = candidate.left + candidate.width;
  final double overlap =
      math.min(lastRight, candidateRight) - math.max(lastLeft, candidateLeft);
  final double overlapRatio = overlap / math.min(last.width, candidate.width);
  if (overlapRatio >= _minOverlapRatio) {
    return overlapRatio;
  }
  final double lastCenter = last.left + last.width / 2;
  final double candidateCenter = candidate.left + candidate.width / 2;
  final double centerDistance = (candidateCenter - lastCenter).abs();
  if (centerDistance <=
      _maxCenterOffsetRatio * math.max(last.width, candidate.width)) {
    final double fit =
        1 - centerDistance / math.max(last.width, candidate.width);
    return 0.1 + 0.5 * fit;
  }
  return null;
}

/// Merge score for tategaki (vertical text) pages: columns of one bubble sit
/// side by side — a small horizontal gap between their x-extents and a large
/// vertical overlap — unlike horizontal lines, which stack vertically.
double? _verticalGroupMatchScore(
  RecognizedTextBlock last,
  RecognizedTextBlock candidate,
) {
  final double lastBottom = last.top + last.height;
  final double lastRight = last.left + last.width;
  final double candidateBottom = candidate.top + candidate.height;
  final double candidateRight = candidate.left + candidate.width;

  // Must overlap vertically (side-by-side columns, not stacked bubbles).
  final double verticalOverlap =
      math.min(lastBottom, candidateBottom) - math.max(last.top, candidate.top);
  if (verticalOverlap < 0.5 * math.min(last.height, candidate.height)) {
    return null;
  }

  // Horizontally close: the gap between the two x-extents must be small
  // relative to the narrower column. Symmetric, so it works whether the next
  // column is to the left (RTL reading order) or right.
  final double horizontalGap = math.max(
    math.max(last.left - candidateRight, candidate.left - lastRight),
    0,
  );
  final double maxGap =
      _maxColumnGapRatio * math.min(last.width, candidate.width);
  if (horizontalGap > maxGap) {
    return null;
  }
  return 1 - horizontalGap / maxGap;
}
