import 'dart:math' as math;

import 'package:jhentai/src/utils/oriented_rect.dart';
import 'package:jhentai/src/utils/ocr_layout_protocol.dart';

/// Ground-truth region used by the repeatable manga OCR acceptance fixture.
class MangaOcrEvalRegion {
  const MangaOcrEvalRegion({
    required this.id,
    required this.text,
    required this.polygon,
  });

  final String id;
  final String text;
  final List<OcrPoint> polygon;
}

/// Adapter output consumed by the same evaluator regardless of detector or
/// recognizer implementation.
class MangaOcrEvalPrediction {
  const MangaOcrEvalPrediction({
    required this.text,
    required this.polygon,
    this.confidence = 1,
    this.sourceIndex = 0,
  });

  final String text;
  final List<OcrPoint> polygon;
  final double confidence;
  final int sourceIndex;
}

class MangaOcrEvalReport {
  const MangaOcrEvalReport({
    required this.truePositives,
    required this.falsePositives,
    required this.missed,
    required this.detectionPrecision,
    required this.detectionRecall,
    required this.detectionF1,
    required this.recognitionCer,
    required this.recognitionAccuracy,
    required this.orderAccuracy,
  });

  final int truePositives;
  final int falsePositives;
  final int missed;
  final double detectionPrecision;
  final double detectionRecall;
  final double detectionF1;
  final double recognitionCer;
  final double recognitionAccuracy;
  final double orderAccuracy;
}

MangaOcrEvalReport evaluateMangaOcrCase({
  required List<MangaOcrEvalRegion> groundTruth,
  required List<MangaOcrEvalPrediction> predictions,
  double iouThreshold = OcrScoringProtocol.detectionIoUThreshold,
}) {
  final List<_Match> matches = <_Match>[];
  final Set<int> usedGroundTruth = <int>{};
  final List<(int, int, double)> candidates = <(int, int, double)>[];
  for (int prediction = 0; prediction < predictions.length; prediction++) {
    for (int truth = 0; truth < groundTruth.length; truth++) {
      candidates.add((
        prediction,
        truth,
        polygonIoU(predictions[prediction].polygon, groundTruth[truth].polygon),
      ));
    }
  }
  candidates.sort((a, b) {
    final int iou = b.$3.compareTo(a.$3);
    if (iou != 0) return iou;
    final int prediction = a.$1.compareTo(b.$1);
    return prediction != 0 ? prediction : a.$2.compareTo(b.$2);
  });
  final Set<int> usedPredictions = <int>{};
  for (final (int prediction, int truth, double iou) in candidates) {
    if (iou < iouThreshold ||
        usedPredictions.contains(prediction) ||
        usedGroundTruth.contains(truth)) {
      continue;
    }
    usedPredictions.add(prediction);
    usedGroundTruth.add(truth);
    matches.add(_Match(prediction, truth));
  }
  matches.sort((a, b) => a.prediction.compareTo(b.prediction));
  final int truePositives = matches.length;
  final int falsePositives = predictions.length - truePositives;
  final int missed = groundTruth.length - truePositives;
  final double precision = predictions.isEmpty
      ? (groundTruth.isEmpty ? 1 : 0)
      : truePositives / predictions.length;
  final double recall = groundTruth.isEmpty
      ? (predictions.isEmpty ? 1 : 0)
      : truePositives / groundTruth.length;
  final double f1 = precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);
  final double cer = matches.isEmpty
      ? (groundTruth.isEmpty && predictions.isEmpty ? 0 : 1)
      : matches
                .map(
                  (_Match match) => characterErrorRate(
                    predictions[match.prediction].text,
                    groundTruth[match.truth].text,
                  ),
                )
                .reduce((double a, double b) => a + b) /
            matches.length;
  final double order = _orderAccuracy(matches);
  return MangaOcrEvalReport(
    truePositives: truePositives,
    falsePositives: falsePositives,
    missed: missed,
    detectionPrecision: precision,
    detectionRecall: recall,
    detectionF1: f1,
    recognitionCer: cer,
    recognitionAccuracy: (1 - cer).clamp(0, 1).toDouble(),
    orderAccuracy: order,
  );
}

double characterErrorRate(String expected, String actual) {
  final List<int> target = _normalize(expected).runes.toList(growable: false);
  final List<int> value = _normalize(actual).runes.toList(growable: false);
  if (target.isEmpty) return value.isEmpty ? 0 : 1;
  final List<int> previous = List<int>.generate(
    value.length + 1,
    (int index) => index,
  );
  for (int i = 1; i <= target.length; i++) {
    final List<int> current = List<int>.filled(value.length + 1, 0);
    current[0] = i;
    for (int j = 1; j <= value.length; j++) {
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + (target[i - 1] == value[j - 1] ? 0 : 1),
      );
    }
    previous.setAll(0, current);
  }
  return previous.last / target.length;
}

double polygonIoU(List<OcrPoint> first, List<OcrPoint> second) {
  if (first.length < 3 || second.length < 3) return 0;
  final List<OcrPoint> a = convexHull(first);
  final List<OcrPoint> b = convexHull(second);
  final double areaA = _polygonArea(a);
  final double areaB = _polygonArea(b);
  if (areaA <= 0 || areaB <= 0) return 0;
  final double intersection = _polygonArea(_clipPolygon(a, b));
  final double union = areaA + areaB - intersection;
  return union <= 0 ? 0 : (intersection / union).clamp(0, 1).toDouble();
}

String _normalize(String value) => value.trim().replaceAll(RegExp(r'\s+'), '');

double _orderAccuracy(List<_Match> matches) {
  if (matches.length < 2) return 1;
  int inversions = 0;
  for (int i = 0; i < matches.length; i++) {
    for (int j = i + 1; j < matches.length; j++) {
      if (matches[i].truth > matches[j].truth) inversions++;
    }
  }
  final int pairs = matches.length * (matches.length - 1) ~/ 2;
  return (1 - inversions / pairs).clamp(0, 1).toDouble();
}

double _polygonArea(List<OcrPoint> polygon) {
  if (polygon.length < 3) return 0;
  double area = 0;
  for (int i = 0; i < polygon.length; i++) {
    final OcrPoint a = polygon[i];
    final OcrPoint b = polygon[(i + 1) % polygon.length];
    area += a.$1 * b.$2 - b.$1 * a.$2;
  }
  return area.abs() / 2;
}

List<OcrPoint> _clipPolygon(List<OcrPoint> subject, List<OcrPoint> clip) {
  List<OcrPoint> output = List<OcrPoint>.of(subject);
  for (int i = 0; i < clip.length; i++) {
    if (output.isEmpty) break;
    final OcrPoint edgeStart = clip[i];
    final OcrPoint edgeEnd = clip[(i + 1) % clip.length];
    final List<OcrPoint> input = output;
    output = <OcrPoint>[];
    OcrPoint previous = input.last;
    bool previousInside = _cross(edgeStart, edgeEnd, previous) >= -1e-9;
    for (final OcrPoint current in input) {
      final bool currentInside = _cross(edgeStart, edgeEnd, current) >= -1e-9;
      if (currentInside != previousInside) {
        output.add(_lineIntersection(previous, current, edgeStart, edgeEnd));
      }
      if (currentInside) output.add(current);
      previous = current;
      previousInside = currentInside;
    }
  }
  return output;
}

double _cross(OcrPoint origin, OcrPoint a, OcrPoint b) =>
    (a.$1 - origin.$1) * (b.$2 - origin.$2) -
    (a.$2 - origin.$2) * (b.$1 - origin.$1);

OcrPoint _lineIntersection(OcrPoint a, OcrPoint b, OcrPoint c, OcrPoint d) {
  final double abx = b.$1 - a.$1;
  final double aby = b.$2 - a.$2;
  final double cdx = d.$1 - c.$1;
  final double cdy = d.$2 - c.$2;
  final double denominator = abx * cdy - aby * cdx;
  if (denominator.abs() < 1e-9) return b;
  final double acx = c.$1 - a.$1;
  final double acy = c.$2 - a.$2;
  final double t = (acx * cdy - acy * cdx) / denominator;
  return (a.$1 + t * abx, a.$2 + t * aby);
}

class _Match {
  const _Match(this.prediction, this.truth);

  final int prediction;
  final int truth;
}
