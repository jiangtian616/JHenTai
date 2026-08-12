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

/// Returns the text units used by translation and rendering. When automatic
/// merging is disabled, every OCR block remains an independent unit so the
/// translation and embedding mapping stays strictly one-to-one.
List<RecognizedTextGroup> translationTextGroups(
  List<RecognizedTextBlock> blocks, {
  bool merge = true,
  List<RecognizedTextContainer> containers = const <RecognizedTextContainer>[],
}) {
  if (merge && containers.isNotEmpty) {
    final Set<int> assigned = <int>{};
    final List<RecognizedTextGroup> result = <RecognizedTextGroup>[];
    for (final RecognizedTextContainer container in containers) {
      final List<int> indices = container.blockIndices
          .where((int index) => index >= 0 && index < blocks.length)
          .toList(growable: false);
      if (indices.isEmpty || indices.any(assigned.contains)) continue;
      assigned.addAll(indices);
      result.add(
        RecognizedTextGroup(
          blockIndices: indices,
          left: container.left,
          top: container.top,
          right: container.left + container.width,
          bottom: container.top + container.height,
        ),
      );
    }
    final List<int> remaining = <int>[];
    for (int index = 0; index < blocks.length; index++) {
      if (!assigned.contains(index)) remaining.add(index);
    }
    if (remaining.isNotEmpty) {
      result.addAll(
        groupRecognizedTextBlocks(
          remaining.map((int index) => blocks[index]).toList(growable: false),
        ).map(
          (RecognizedTextGroup group) => RecognizedTextGroup(
            blockIndices: group.blockIndices
                .map((int local) => remaining[local])
                .toList(growable: false),
            left: group.left,
            top: group.top,
            right: group.right,
            bottom: group.bottom,
          ),
        ),
      );
    }
    return result;
  }
  if (merge) {
    return groupRecognizedTextBlocks(blocks);
  }
  return <RecognizedTextGroup>[
    for (int index = 0; index < blocks.length; index++)
      RecognizedTextGroup(
        blockIndices: <int>[index],
        left: blocks[index].left,
        top: blocks[index].top,
        right: blocks[index].left + blocks[index].width,
        bottom: blocks[index].top + blocks[index].height,
      ),
  ];
}

/// The rectangle used when painting one translated utterance.
///
/// OCR boxes are glyph/line boxes, not the whole speech bubble.  Keeping this
/// small value object next to the grouping code makes the same conservative
/// expansion available to the live overlay and exported PNG renderer.
class RecognizedTextGroupRenderBounds {
  const RecognizedTextGroupRenderBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => math.max(0.0, right - left);
  double get height => math.max(0.0, bottom - top);
}

/// Whether [group] has the stable geometry of a multi-line text container.
///
/// This is deliberately a geometry-only heuristic.  CTD's current output is
/// a text-pixel mask rather than a speech-bubble boundary, so a single line
/// cannot be safely classified as a bubble without looking at the source
/// pixels.  Multi-line groups with consistent stacking/column spacing are the
/// safe subset; everything else keeps the OCR-box fallback.
bool isRecognizedTextContainerCandidate(
  RecognizedTextGroup group,
  List<RecognizedTextBlock> blocks,
) {
  if (group.blockIndices.length < 2) {
    return false;
  }
  final List<RecognizedTextBlock> members = group.blocksOf(blocks);
  if (members.any(
    (RecognizedTextBlock block) => block.width <= 0 || block.height <= 0,
  )) {
    return false;
  }
  final bool vertical = _isMostlyVertical(members);
  if (vertical) {
    // Vertical columns of one container overlap in y and sit at a regular
    // horizontal distance.  groupRecognizedTextBlocks already enforces this;
    // the explicit check keeps this helper safe for callers with hand-built
    // groups as well.
    final List<RecognizedTextBlock> ordered = [...members]
      ..sort((a, b) => b.left.compareTo(a.left));
    for (int index = 1; index < ordered.length; index++) {
      final RecognizedTextBlock previous = ordered[index - 1];
      final RecognizedTextBlock current = ordered[index];
      final double overlap =
          math.min(
            previous.top + previous.height,
            current.top + current.height,
          ) -
          math.max(previous.top, current.top);
      if (overlap < 0.45 * math.min(previous.height, current.height)) {
        return false;
      }
    }
    return true;
  }

  final List<RecognizedTextBlock> ordered = [...members]
    ..sort((a, b) => a.top.compareTo(b.top));
  final double medianHeight = _median(
    ordered.map((RecognizedTextBlock block) => block.height).toList(),
  );
  if (medianHeight <= 0) {
    return false;
  }
  for (int index = 1; index < ordered.length; index++) {
    final RecognizedTextBlock previous = ordered[index - 1];
    final RecognizedTextBlock current = ordered[index];
    final double gap = current.top - (previous.top + previous.height);
    if (gap > 1.8 * medianHeight) {
      return false;
    }
    final double previousCenter = previous.left + previous.width / 2;
    final double currentCenter = current.left + current.width / 2;
    if ((currentCenter - previousCenter).abs() >
        math.max(group.width * 0.55, medianHeight * 3)) {
      return false;
    }
  }
  return true;
}

/// Returns the explicit container bounds when OCR has a matching detector
/// result, otherwise null.  We intentionally do not manufacture a bubble from
/// an OCR union: the union describes text, not the enclosing artwork.
RecognizedTextGroupRenderBounds? explicitRenderBoundsForRecognizedTextGroup(
  RecognizedTextGroup group,
  List<RecognizedTextContainer> containers,
) {
  for (final RecognizedTextContainer container in containers) {
    if (container.blockIndices.length != group.blockIndices.length ||
        !container.blockIndices.toSet().containsAll(group.blockIndices)) {
      continue;
    }
    return RecognizedTextGroupRenderBounds(
      left: container.left,
      top: container.top,
      right: container.left + container.width,
      bottom: container.top + container.height,
    );
  }
  return null;
}

/// Returns one conservative render rectangle for [group].
///
/// Multi-line horizontal groups get a margin based on their line height. For
/// vertical text, the translated Chinese is laid out horizontally, so the
/// narrow OCR union is widened to a fraction of the original column height.
/// Single-line/uncertain groups return the OCR union with only the renderer's
/// existing small inset, preserving the safe fallback behaviour.
RecognizedTextGroupRenderBounds renderBoundsForRecognizedTextGroup(
  RecognizedTextGroup group,
  List<RecognizedTextBlock> blocks, {
  RecognizedTextContainer? container,
}) {
  if (container != null && container.width > 0 && container.height > 0) {
    return RecognizedTextGroupRenderBounds(
      left: container.left,
      top: container.top,
      right: container.left + container.width,
      bottom: container.top + container.height,
    );
  }
  return RecognizedTextGroupRenderBounds(
    left: group.left,
    top: group.top,
    right: group.right,
    bottom: group.bottom,
  );
}

double _median(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final List<double> sorted = [...values]..sort();
  final int middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Builds the compact, group-level source used by translation engines. A
/// group is one visual utterance, so its source lines remain together instead
/// of teaching the model to translate detector fragments independently.
String buildGroupedTranslationSource(
  List<RecognizedTextBlock> blocks,
  List<RecognizedTextGroup> groups,
) {
  final StringBuffer source = StringBuffer();
  for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    source.writeln('Group ${groupIndex + 1}:');
    source.writeln(groups[groupIndex].textOf(blocks));
  }
  return source.toString();
}

/// Parses the numbered group format requested by the API/local engines.
///
/// Older cached/local runtimes may still return one number per OCR line. When
/// [legacyCount] is supplied and the response contains a number outside the
/// group range, the same text is parsed using that legacy line count so a
/// model upgrade does not silently shift translations onto the wrong bubble.
List<String> parseNumberedTranslations(
  String text,
  int count, {
  int? legacyCount,
}) {
  final List<int> numbers =
      RegExp(
        r'^\s*(?:group\s*)?(\d+)\s*[:：.)-]?',
        caseSensitive: false,
        multiLine: true,
      ).allMatches(text).map((match) => int.parse(match.group(1)!)).toList();
  final int largest = numbers.isEmpty ? 0 : numbers.reduce(math.max);
  if (legacyCount != null && largest > count) {
    return _parseNumberedTranslations(text, legacyCount);
  }
  return _parseNumberedTranslations(text, count);
}

List<String> _parseNumberedTranslations(String text, int count) {
  final List<String?> result = List<String?>.filled(count, null);
  int fallbackIndex = 0;
  for (final String rawLine in text.split('\n')) {
    final String line = rawLine.replaceFirst(RegExp(r'^\s*[-*]\s+'), '').trim();
    if (line.isEmpty ||
        RegExp(
          r'^\s*(?:group\s*)?\d+\s*:?\s*$',
          caseSensitive: false,
        ).hasMatch(line)) {
      continue;
    }
    final RegExpMatch? match = RegExp(
      r'^\s*(?:group\s*)?(\d+)\s*[:：.)-]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    final int? index = match == null ? null : int.tryParse(match.group(1)!);
    if (index != null && index >= 1 && index <= count) {
      result[index - 1] = match!.group(2)!.trim();
      fallbackIndex = math.max(fallbackIndex, index);
      continue;
    }
    while (fallbackIndex < count && result[fallbackIndex] != null) {
      fallbackIndex++;
    }
    if (fallbackIndex < count) {
      result[fallbackIndex++] = line;
    }
  }
  return result.map((String? line) => line ?? '').toList(growable: false);
}

/// Expands one translated utterance per group back to the detector's blocks.
/// The renderer can then keep a stable 1:1 block mapping while displaying the
/// group as a single coherent text layout.
List<String> expandGroupTranslationsToLines({
  required List<RecognizedTextBlock> blocks,
  required List<RecognizedTextGroup> groups,
  required List<String> groupTranslations,
}) {
  final List<String> lines = List<String>.filled(blocks.length, '');
  for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final RecognizedTextGroup group = groups[groupIndex];
    final String translation =
        groupIndex < groupTranslations.length
            ? groupTranslations[groupIndex]
            : '';
    final List<String> sourceLines = group.blockIndices
        .map((int index) => blocks[index].text)
        .toList(growable: false);
    final List<String> split = splitGroupTranslationIntoLines(
      translation: translation,
      sourceLines: sourceLines,
    );
    for (
      int lineIndex = 0;
      lineIndex < group.blockIndices.length;
      lineIndex++
    ) {
      lines[group.blockIndices[lineIndex]] =
          lineIndex < split.length ? split[lineIndex] : '';
    }
  }
  return lines;
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
  final List<String> byNewline =
      const LineSplitter()
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
  final List<int> weights =
      sourceLines
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
      final double? score =
          mostlyVertical
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
    // A small edge overlap is not enough to prove that two lines belong to
    // one bubble. In 00.33.31, for example, the last line of the left bubble
    // overlaps the first line of the right bubble by ~25%, which previously
    // merged two separate utterances and destroyed translation context.
    final double lastCenter = last.left + last.width / 2;
    final double candidateCenter = candidate.left + candidate.width / 2;
    final double centerDistance = (candidateCenter - lastCenter).abs();
    if (overlapRatio >= 0.55 ||
        centerDistance <=
            _maxCenterOffsetRatio * math.max(last.width, candidate.width)) {
      return overlapRatio;
    }
    return null;
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
