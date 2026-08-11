import 'dart:math' as math;

import 'package:image/image.dart' as image;

import 'oriented_rect.dart';

/// Rectifies a quadrilateral into an axis-aligned image for OCR.
///
/// [corners] may be in any winding order; they are canonicalized to
/// top-left, top-right, bottom-right, bottom-left. A projective homography is
/// used instead of an axis-aligned crop plus rotation, so keystone distortion
/// from comic-page scans is corrected before recognition.
image.Image? perspectiveStraightenOcrCrop(
  image.Image source,
  List<OcrPoint> corners,
) {
  if (corners.length != 4 || source.width < 2 || source.height < 2) {
    return null;
  }
  final List<OcrPoint> quad = _canonicalizeQuad(corners);
  final double minX = quad.map((OcrPoint p) => p.$1).reduce(math.min);
  final double maxX = quad.map((OcrPoint p) => p.$1).reduce(math.max);
  final double minY = quad.map((OcrPoint p) => p.$2).reduce(math.min);
  final double maxY = quad.map((OcrPoint p) => p.$2).reduce(math.max);
  if (maxX < 0 || minX >= source.width || maxY < 0 || minY >= source.height) {
    return null;
  }
  final double topWidth = _distance(quad[0], quad[1]);
  final double bottomWidth = _distance(quad[3], quad[2]);
  final double leftHeight = _distance(quad[0], quad[3]);
  final double rightHeight = _distance(quad[1], quad[2]);
  final int outputWidth = math.max(2, math.max(topWidth, bottomWidth).round());
  final int outputHeight = math.max(
    2,
    math.max(leftHeight, rightHeight).round(),
  );
  final List<double>? h = _solveHomography(
    quad,
    outputWidth.toDouble(),
    outputHeight.toDouble(),
  );
  if (h == null) return null;

  final image.Image result = image.Image(
    width: outputWidth,
    height: outputHeight,
    numChannels: 3,
  );
  for (int y = 0; y < outputHeight; y++) {
    for (int x = 0; x < outputWidth; x++) {
      final double denominator = h[6] * (x + 0.5) + h[7] * (y + 0.5) + 1;
      if (denominator.abs() < 1e-9) continue;
      final double sourceX =
          (h[0] * (x + 0.5) + h[1] * (y + 0.5) + h[2]) / denominator;
      final double sourceY =
          (h[3] * (x + 0.5) + h[4] * (y + 0.5) + h[5]) / denominator;
      final (int r, int g, int b) rgb = _sampleRgb(source, sourceX, sourceY);
      result.setPixelRgb(x, y, rgb.$1, rgb.$2, rgb.$3);
    }
  }
  return result;
}

List<OcrPoint> _canonicalizeQuad(List<OcrPoint> corners) {
  final double cx =
      corners.map((OcrPoint p) => p.$1).reduce((double a, double b) => a + b) /
      corners.length;
  final double cy =
      corners.map((OcrPoint p) => p.$2).reduce((double a, double b) => a + b) /
      corners.length;
  final List<OcrPoint> ordered = List<OcrPoint>.of(corners)
    ..sort((OcrPoint a, OcrPoint b) {
      final double aa = math.atan2(a.$2 - cy, a.$1 - cx);
      final double ab = math.atan2(b.$2 - cy, b.$1 - cx);
      return aa.compareTo(ab);
    });
  int topLeft = 0;
  for (int i = 1; i < ordered.length; i++) {
    if (ordered[i].$1 + ordered[i].$2 <
        ordered[topLeft].$1 + ordered[topLeft].$2) {
      topLeft = i;
    }
  }
  return <OcrPoint>[
    for (int i = 0; i < ordered.length; i++) ordered[(topLeft + i) % 4],
  ];
}

double _distance(OcrPoint a, OcrPoint b) {
  final double dx = a.$1 - b.$1;
  final double dy = a.$2 - b.$2;
  return math.sqrt(dx * dx + dy * dy);
}

List<double>? _solveHomography(
  List<OcrPoint> source,
  double width,
  double height,
) {
  final List<(double, double)> destination = <(double, double)>[
    (0, 0),
    (width, 0),
    (width, height),
    (0, height),
  ];
  final List<List<double>> matrix = <List<double>>[];
  final List<double> values = <double>[];
  for (int i = 0; i < 4; i++) {
    final double u = destination[i].$1;
    final double v = destination[i].$2;
    final double x = source[i].$1;
    final double y = source[i].$2;
    matrix.add(<double>[u, v, 1, 0, 0, 0, -x * u, -x * v]);
    values.add(x);
    matrix.add(<double>[0, 0, 0, u, v, 1, -y * u, -y * v]);
    values.add(y);
  }
  for (int pivot = 0; pivot < 8; pivot++) {
    int best = pivot;
    for (int row = pivot + 1; row < 8; row++) {
      if (matrix[row][pivot].abs() > matrix[best][pivot].abs()) best = row;
    }
    if (matrix[best][pivot].abs() < 1e-9) return null;
    final List<double> row = matrix[pivot];
    matrix[pivot] = matrix[best];
    matrix[best] = row;
    final double value = values[pivot];
    values[pivot] = values[best];
    values[best] = value;
    final double divisor = matrix[pivot][pivot];
    for (int col = pivot; col < 8; col++) {
      matrix[pivot][col] /= divisor;
    }
    values[pivot] /= divisor;
    for (int rowIndex = 0; rowIndex < 8; rowIndex++) {
      if (rowIndex == pivot) continue;
      final double factor = matrix[rowIndex][pivot];
      if (factor.abs() < 1e-12) continue;
      for (int col = pivot; col < 8; col++) {
        matrix[rowIndex][col] -= factor * matrix[pivot][col];
      }
      values[rowIndex] -= factor * values[pivot];
    }
  }
  return values;
}

(int, int, int) _sampleRgb(image.Image source, double x, double y) {
  final double px = x.clamp(0, source.width - 1).toDouble();
  final double py = y.clamp(0, source.height - 1).toDouble();
  final int x0 = px.floor();
  final int y0 = py.floor();
  final int x1 = math.min(source.width - 1, x0 + 1);
  final int y1 = math.min(source.height - 1, y0 + 1);
  final double dx = px - x0;
  final double dy = py - y0;
  final image.Pixel p00 = source.getPixel(x0, y0);
  final image.Pixel p10 = source.getPixel(x1, y0);
  final image.Pixel p01 = source.getPixel(x0, y1);
  final image.Pixel p11 = source.getPixel(x1, y1);
  int blend(num a, num b, num c, num d) =>
      (a * (1 - dx) * (1 - dy) +
              b * dx * (1 - dy) +
              c * (1 - dx) * dy +
              d * dx * dy)
          .round()
          .clamp(0, 255)
          .toInt();
  return (
    blend(p00.r, p10.r, p01.r, p11.r),
    blend(p00.g, p10.g, p01.g, p11.g),
    blend(p00.b, p10.b, p01.b, p11.b),
  );
}
