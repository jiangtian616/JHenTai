import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/utils/oriented_rect.dart';

List<OcrPoint> _bar({
  required double cx,
  required double cy,
  required double length,
  required double thickness,
  required double angleDeg,
}) {
  final double rad = angleDeg * math.pi / 180;
  final double cosA = math.cos(rad);
  final double sinA = math.sin(rad);
  final List<OcrPoint> points = <OcrPoint>[];
  const int lenSteps = 40;
  const int thickSteps = 12;
  for (int i = 0; i < lenSteps; i++) {
    for (int j = 0; j < thickSteps; j++) {
      final double along = -length / 2 + length * i / (lenSteps - 1);
      final double across = -thickness / 2 + thickness * j / (thickSteps - 1);
      points.add((
        cx + along * cosA - across * sinA,
        cy + along * sinA + across * cosA,
      ));
    }
  }
  return points;
}

void main() {
  group('minAreaRect', () {
    test('axis-aligned horizontal bar', () {
      final OrientedRect r = minAreaRect(_bar(
        cx: 500,
        cy: 300,
        length: 200,
        thickness: 20,
        angleDeg: 0,
      ));
      expect(r.width, closeTo(200, 2));
      expect(r.height, closeTo(20, 2));
      expect(r.angle.abs(), lessThan(0.05));
      expect(r.cx, closeTo(500, 1));
      expect(r.cy, closeTo(300, 1));
    });

    test('bar rotated 30 degrees', () {
      final OrientedRect r = minAreaRect(_bar(
        cx: 500,
        cy: 300,
        length: 200,
        thickness: 20,
        angleDeg: 30,
      ));
      expect(r.width, closeTo(200, 3));
      expect(r.height, closeTo(20, 3));
      // Angle normalized to [-90, 90]; a 30-deg bar is ~30 deg from x-axis.
      expect(r.angle * 180 / math.pi, closeTo(30, 3));
    });

    test('vertical column reports the long axis as width', () {
      final OrientedRect r = minAreaRect(_bar(
        cx: 300,
        cy: 500,
        length: 300, // tall column
        thickness: 24,
        angleDeg: 90,
      ));
      expect(r.width, closeTo(300, 3));
      expect(r.height, closeTo(24, 3));
      // Long axis is vertical.
      expect((r.angle * 180 / math.pi).abs(), closeTo(90, 3));
    });

    test('degenerate point set falls back to a bbox', () {
      final OrientedRect r = minAreaRect(const <OcrPoint>[
        (10, 10),
        (30, 10),
        (30, 40),
      ]);
      expect(r.width, greaterThanOrEqualTo(r.height));
    });
  });

  group('unclipOrientedRect', () {
    test('grows the rect by the area-based distance', () {
      final OrientedRect r = unclipOrientedRect(
        const OrientedRect(
          cx: 0,
          cy: 0,
          width: 200,
          height: 20,
          angle: 0,
        ),
      );
      // distance = 200*20*1.6/(2*220) = 14.545...; each dim + 2*distance.
      expect(r.width, closeTo(200 + 2 * 14.545454, 0.1));
      expect(r.height, closeTo(20 + 2 * 14.545454, 0.1));
      expect(r.angle, 0);
    });
  });

  group('corners / bbox', () {
    test('bbox of an axis-aligned rect equals its dims', () {
      const OrientedRect r = OrientedRect(
        cx: 100,
        cy: 100,
        width: 200,
        height: 20,
        angle: 0,
      );
      final (double left, double top, double w, double h) = r.bbox;
      expect(left, closeTo(0, 1e-6));
      expect(top, closeTo(90, 1e-6));
      expect(w, closeTo(200, 1e-6));
      expect(h, closeTo(20, 1e-6));
    });

    test('bbox of a 45-degree rect is the enclosing square', () {
      final OrientedRect r = OrientedRect(
        cx: 0,
        cy: 0,
        width: 100,
        height: 100,
        angle: 45 * math.pi / 180,
      );
      final (double left, double top, double w, double h) = r.bbox;
      // A 45-deg 100x100 square spans ~141.4 along both axes.
      expect(w, closeTo(141.421356, 0.5));
      expect(h, closeTo(141.421356, 0.5));
      expect(left, closeTo(-70.710678, 0.5));
      expect(top, closeTo(-70.710678, 0.5));
    });
  });
}
