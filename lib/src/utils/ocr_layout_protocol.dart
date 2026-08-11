import 'dart:math' as math;

import '../model/image_translation.dart';

/// The reading-order contract shared by detectors, recognizers, grouping and
/// the evaluation fixture. Coordinates are in the upright image space.
enum OcrLayoutMode { horizontalLtr, verticalRtl }

/// Geometry needed by the layout sorter. [sourceIndex] makes the result stable
/// without requiring callers to mutate their own model objects.
class OcrLayoutBox {
  const OcrLayoutBox({
    required this.sourceIndex,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int sourceIndex;
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

/// Thresholds are deliberately shared by runtime and evaluation code. A
/// change here changes both the detector's acceptance boundary and the
/// reported benchmark, so it cannot silently drift between implementations.
class OcrScoringProtocol {
  const OcrScoringProtocol._();

  static const double detectorPixelThreshold = 0.3;
  static const double detectorBoxThreshold = 0.5;
  static const double recognitionConfidenceThreshold = 0.5;
  static const double verticalAspectRatio = 1.4;
  static const double detectionIoUThreshold = 0.5;
}

OcrLayoutMode classifyOcrLayout(Iterable<OcrLayoutBox> boxes) {
  int total = 0;
  int vertical = 0;
  for (final OcrLayoutBox box in boxes) {
    if (box.width <= 0 || box.height <= 0) continue;
    total++;
    if (box.height > box.width * OcrScoringProtocol.verticalAspectRatio) {
      vertical++;
    }
  }
  return total > 0 && vertical * 2 > total
      ? OcrLayoutMode.verticalRtl
      : OcrLayoutMode.horizontalLtr;
}

/// Sorts boxes into manga reading order: columns right-to-left for dominant
/// vertical text, or rows top-to-bottom and left-to-right otherwise.
///
/// Column/row membership uses geometry rather than input order. This matters
/// for rotated detector output and for adapters whose native result order is
/// unspecified. Ties always fall back to [sourceIndex].
List<OcrLayoutBox> sortOcrReadingOrder(List<OcrLayoutBox> input) {
  if (input.length < 2) return List<OcrLayoutBox>.of(input);
  final OcrLayoutMode mode = classifyOcrLayout(input);
  return mode == OcrLayoutMode.verticalRtl
      ? _sortVertical(input)
      : _sortHorizontal(input);
}

List<RecognizedTextBlock> sortRecognizedTextBlocks(
  List<RecognizedTextBlock> blocks,
) {
  final List<OcrLayoutBox> boxes = <OcrLayoutBox>[
    for (int i = 0; i < blocks.length; i++)
      OcrLayoutBox(
        sourceIndex: i,
        left: blocks[i].left,
        top: blocks[i].top,
        width: blocks[i].width,
        height: blocks[i].height,
      ),
  ];
  return sortOcrReadingOrder(
    boxes,
  ).map((OcrLayoutBox box) => blocks[box.sourceIndex]).toList(growable: false);
}

List<OcrLayoutBox> _sortVertical(List<OcrLayoutBox> input) {
  final List<OcrLayoutBox> byColumn = List<OcrLayoutBox>.of(input)
    ..sort((OcrLayoutBox a, OcrLayoutBox b) {
      final int x = b.centerX.compareTo(a.centerX);
      return x != 0 ? x : a.top.compareTo(b.top);
    });
  final List<_OcrColumn> columns = <_OcrColumn>[];
  for (final OcrLayoutBox box in byColumn) {
    _OcrColumn? best;
    double bestDistance = double.infinity;
    for (final _OcrColumn column in columns) {
      final double overlap =
          math.min(box.right, column.right) - math.max(box.left, column.left);
      final double overlapRatio =
          overlap / math.max(1, math.min(box.width, column.width));
      final double distance = (box.centerX - column.centerX).abs();
      final double tolerance = math.max(
        8,
        1.5 * math.max(box.width, column.width),
      );
      if (overlapRatio >= 0.2 || distance <= tolerance) {
        if (distance < bestDistance) {
          best = column;
          bestDistance = distance;
        }
      }
    }
    (best ??= _OcrColumn()).boxes.add(box);
    if (!columns.contains(best)) columns.add(best);
  }
  for (final _OcrColumn column in columns) {
    column.boxes.sort((OcrLayoutBox a, OcrLayoutBox b) {
      final int y = a.top.compareTo(b.top);
      return y != 0 ? y : a.sourceIndex.compareTo(b.sourceIndex);
    });
  }
  columns.sort((_OcrColumn a, _OcrColumn b) {
    final int x = b.centerX.compareTo(a.centerX);
    return x != 0 ? x : a.firstTop.compareTo(b.firstTop);
  });
  return <OcrLayoutBox>[
    for (final _OcrColumn column in columns) ...column.boxes,
  ];
}

List<OcrLayoutBox> _sortHorizontal(List<OcrLayoutBox> input) {
  final List<OcrLayoutBox> byRow = List<OcrLayoutBox>.of(input)
    ..sort((OcrLayoutBox a, OcrLayoutBox b) {
      final int y = a.top.compareTo(b.top);
      return y != 0 ? y : a.left.compareTo(b.left);
    });
  final List<_OcrRow> rows = <_OcrRow>[];
  for (final OcrLayoutBox box in byRow) {
    _OcrRow? best;
    double bestDistance = double.infinity;
    for (final _OcrRow row in rows) {
      final double verticalOverlap =
          math.min(box.bottom, row.bottom) - math.max(box.top, row.top);
      final double overlapRatio =
          verticalOverlap / math.max(1, math.min(box.height, row.height));
      final double distance = (box.centerY - row.centerY).abs();
      final double tolerance = 0.6 * math.max(box.height, row.height);
      if (overlapRatio >= 0.2 || distance <= tolerance) {
        if (distance < bestDistance) {
          best = row;
          bestDistance = distance;
        }
      }
    }
    (best ??= _OcrRow()).boxes.add(box);
    if (!rows.contains(best)) rows.add(best);
  }
  for (final _OcrRow row in rows) {
    row.boxes.sort((OcrLayoutBox a, OcrLayoutBox b) {
      final int x = a.left.compareTo(b.left);
      return x != 0 ? x : a.sourceIndex.compareTo(b.sourceIndex);
    });
  }
  rows.sort((_OcrRow a, _OcrRow b) {
    final int y = a.top.compareTo(b.top);
    return y != 0 ? y : a.firstLeft.compareTo(b.firstLeft);
  });
  return <OcrLayoutBox>[for (final _OcrRow row in rows) ...row.boxes];
}

class _OcrColumn {
  final List<OcrLayoutBox> boxes = <OcrLayoutBox>[];

  double get left => boxes.map((OcrLayoutBox box) => box.left).reduce(math.min);
  double get right =>
      boxes.map((OcrLayoutBox box) => box.right).reduce(math.max);
  double get width => right - left;
  double get centerX => (left + right) / 2;
  double get firstTop =>
      boxes.map((OcrLayoutBox box) => box.top).reduce(math.min);
}

class _OcrRow {
  final List<OcrLayoutBox> boxes = <OcrLayoutBox>[];

  double get top => boxes.map((OcrLayoutBox box) => box.top).reduce(math.min);
  double get bottom =>
      boxes.map((OcrLayoutBox box) => box.bottom).reduce(math.max);
  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
  double get firstLeft =>
      boxes.map((OcrLayoutBox box) => box.left).reduce(math.min);
}
