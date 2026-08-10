import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:jhentai/src/service/inference/onnx_ocr_engine.dart';
import 'package:jhentai/src/utils/oriented_rect.dart';

/// Draws a thick dark bar through (cx, cy) along `angleDeg` and returns its
/// pixel coordinates.
List<OcrPoint> _drawBar(
  image.Image img, {
  required double cx,
  required double cy,
  required double length,
  required double thickness,
  required double angleDeg,
}) {
  final double rad = angleDeg * math.pi / 180;
  final double cosA = math.cos(rad);
  final double sinA = math.sin(rad);
  final List<OcrPoint> pts = <OcrPoint>[];
  for (double along = -length / 2; along <= length / 2; along += 0.5) {
    for (double across = -thickness / 2; across <= thickness / 2; across += 1) {
      final double x = cx + along * cosA - across * sinA;
      final double y = cy + along * sinA + across * cosA;
      pts.add((x, y));
      final int px = x.round().clamp(0, img.width - 1);
      final int py = y.round().clamp(0, img.height - 1);
      img.setPixelRgb(px, py, 0, 0, 0);
    }
  }
  return pts;
}

/// Mean dark-pixel row per column of [img]; null if the column has no dark
/// pixels.
List<double> _meanRowPerColumn(image.Image img) {
  final List<double> means = <double>[];
  for (int x = 0; x < img.width; x++) {
    int count = 0;
    double sum = 0;
    for (int y = 0; y < img.height; y++) {
      final image.Pixel p = img.getPixel(x, y);
      if (p.r < 128 && p.g < 128 && p.b < 128) {
        sum += y;
        count++;
      }
    }
    means.add(count == 0 ? double.nan : sum / count);
  }
  return means;
}

void main() {
  image.Image _blank() {
    final image.Image img = image.Image(width: 320, height: 200, numChannels: 3);
    for (int y = 0; y < img.height; y++) {
      for (int x = 0; x < img.width; x++) {
        img.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    return img;
  }

  test('a 30-degree bar is straightened to horizontal', () {
    final image.Image img = _blank();
    final List<OcrPoint> pts = _drawBar(
      img,
      cx: 160,
      cy: 100,
      length: 180,
      thickness: 14,
      angleDeg: 30,
    );
    final OrientedRect rect = unclipOrientedRect(minAreaRect(pts));
    final image.Image? crop = straightenOcrCrop(img, rect);
    expect(crop, isNotNull);

    // The crop is wide and short: a horizontal line, not a slanted or tall one.
    expect(crop!.width, greaterThan(crop.height * 2));

    // Across the columns, the dark pixels' mean row must be ~constant; a still-
    // slanted bar would drift linearly. Drop the extreme columns where only a
    // few dark pixels exist.
    final List<double> means = _meanRowPerColumn(crop);
    final List<double> valid = <double>[];
    for (int x = 1; x < crop.width - 1; x++) {
      final double m = means[x];
      if (!m.isNaN) {
        valid.add(m);
      }
    }
    expect(valid.length, greaterThan(crop.width * 0.6),
        reason: 'the bar should span most of the crop width');
    final double avg = valid.reduce((a, b) => a + b) / valid.length;
    final double spread =
        valid.map((m) => (m - avg).abs()).reduce(math.max);
    expect(spread, lessThan(2.5),
        reason: 'a straightened horizontal bar has a constant row per column');
  });

  test('an axis-aligned horizontal bar is unchanged in orientation', () {
    final image.Image img = _blank();
    final List<OcrPoint> pts = _drawBar(
      img,
      cx: 160,
      cy: 100,
      length: 180,
      thickness: 14,
      angleDeg: 0,
    );
    final OrientedRect rect = unclipOrientedRect(minAreaRect(pts));
    final image.Image? crop = straightenOcrCrop(img, rect);
    expect(crop, isNotNull);
    expect(crop!.width, greaterThan(crop.height * 2));
    final List<double> valid = _meanRowPerColumn(crop)
        .where((double m) => !m.isNaN)
        .toList();
    final double avg = valid.reduce((a, b) => a + b) / valid.length;
    final double spread =
        valid.map((m) => (m - avg).abs()).reduce(math.max);
    expect(spread, lessThan(2.0));
  });

  test('returns null for a box fully outside the image', () {
    final image.Image img = _blank();
    final OrientedRect rect = const OrientedRect(
      cx: -100,
      cy: -100,
      width: 50,
      height: 10,
      angle: 0,
    );
    expect(straightenOcrCrop(img, rect), isNull);
  });
}
