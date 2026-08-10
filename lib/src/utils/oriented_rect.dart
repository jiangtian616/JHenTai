import 'dart:math' as math;

/// A point in 2D space as a (x, y) record.
typedef OcrPoint = (double, double);

/// Minimal-area oriented rectangle around a text region — the pure-Dart
/// equivalent of OpenCV's `cv2.minAreaRect`. [width] is the long-axis
/// dimension, [height] the short-axis one, and [angle] is the long axis's
/// rotation from the +x axis (radians, in `[-pi/2, pi/2]`, image coordinates
/// with y down).
class OrientedRect {
  const OrientedRect({
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.angle,
  });

  final double cx;
  final double cy;
  final double width;
  final double height;
  final double angle;

  /// The four corners of the rect, ordered [top-left, top-right,
  /// bottom-right, bottom-left] in the rect's local frame.
  List<OcrPoint> get corners {
    final double cosA = math.cos(angle);
    final double sinA = math.sin(angle);
    final double hw = width / 2;
    final double hh = height / 2;
    return <OcrPoint>[
      (cx - hw * cosA + hh * sinA, cy - hw * sinA - hh * cosA),
      (cx + hw * cosA + hh * sinA, cy + hw * sinA - hh * cosA),
      (cx + hw * cosA - hh * sinA, cy + hw * sinA + hh * cosA),
      (cx - hw * cosA - hh * sinA, cy - hw * sinA + hh * cosA),
    ];
  }

  /// The axis-aligned bounding box of this rect: (left, top, width, height).
  (double, double, double, double) get bbox {
    final List<OcrPoint> c = corners;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final (double x, double y) in c) {
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
    return (minX, minY, maxX - minX, maxY - minY);
  }
}

/// Expands [rect] uniformly along its own axes by the DB-unclip distance
/// `area * ratio / perimeter` — the same distance `pyclipper` offsets a DB
/// polygon by, applied to an axis-aligned-in-frame rectangle. [ratio] matches
/// RapidOCR's default `unclip_ratio` of 1.6.
OrientedRect unclipOrientedRect(OrientedRect rect, {double ratio = 1.6}) {
  final double perimeter = 2 * (rect.width + rect.height);
  if (perimeter <= 0) {
    return rect;
  }
  final double distance = rect.width * rect.height * ratio / perimeter;
  return OrientedRect(
    cx: rect.cx,
    cy: rect.cy,
    width: rect.width + 2 * distance,
    height: rect.height + 2 * distance,
    angle: rect.angle,
  );
}

/// Convex hull of [points] (Andrew's monotone chain), returned in
/// counter-clockwise order without collinear interior points.
List<OcrPoint> convexHull(List<OcrPoint> points) {
  if (points.length <= 1) {
    return List<OcrPoint>.of(points);
  }
  final List<OcrPoint> sorted = List<OcrPoint>.of(points)
    ..sort((OcrPoint a, OcrPoint b) {
      final int c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
  double cross(OcrPoint o, OcrPoint a, OcrPoint b) =>
      (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  final List<OcrPoint> lower = <OcrPoint>[];
  for (final OcrPoint p in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final List<OcrPoint> upper = <OcrPoint>[];
  for (final OcrPoint p in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  lower.removeLast();
  upper.removeLast();
  return <OcrPoint>[...lower, ...upper];
}

/// Minimal-area oriented rectangle around [points], via rotating calipers over
/// the convex hull edges. Falls back to the axis-aligned bounding box when the
/// point set is degenerate.
OrientedRect minAreaRect(List<OcrPoint> points) {
  final List<OcrPoint> hull = convexHull(points);
  if (hull.length <= 2) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final (double x, double y) in points) {
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
    return OrientedRect(
      cx: (minX + maxX) / 2,
      cy: (minY + maxY) / 2,
      width: math.max(1, maxX - minX),
      height: math.max(1, maxY - minY),
      angle: 0,
    );
  }

  double bestArea = double.infinity;
  OrientedRect? best;
  for (int i = 0; i < hull.length; i++) {
    final (double ax, double ay) = hull[i];
    final (double bx, double by) = hull[(i + 1) % hull.length];
    final double dx = bx - ax;
    final double dy = by - ay;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) {
      continue;
    }
    final double ex = dx / len;
    final double ey = dy / len;
    final double nx = -ey;
    final double ny = ex;
    double minE = double.infinity;
    double maxE = -double.infinity;
    double minN = double.infinity;
    double maxN = -double.infinity;
    for (final (double px, double py) in hull) {
      final double e = px * ex + py * ey;
      final double n = px * nx + py * ny;
      if (e < minE) {
        minE = e;
      }
      if (e > maxE) {
        maxE = e;
      }
      if (n < minN) {
        minN = n;
      }
      if (n > maxN) {
        maxN = n;
      }
    }
    final double w = maxE - minE;
    final double h = maxN - minN;
    final double area = w * h;
    if (area < bestArea) {
      bestArea = area;
      final double ce = (minE + maxE) / 2;
      final double cn = (minN + maxN) / 2;
      final double cx = ce * ex + cn * nx;
      final double cy = ce * ey + cn * ny;
      final double angle = _normalizeAngle(math.atan2(ey, ex));
      // The e-axis is the long one only when the edge direction happens to be
      // the longer dimension; for very tall components the hull may enumerate
      // the short edge first. Keep (w along e, h along n) and let the caller
      // interpret — but for OCR the long axis is the text direction, so if h
      // ends up larger we swap so width is always the long dimension.
      best = OrientedRect(
        cx: cx,
        cy: cy,
        width: math.max(w, h),
        height: math.min(w, h),
        angle: w >= h ? angle : _normalizeAngle(angle + math.pi / 2),
      );
    }
  }
  return best!;
}

double _normalizeAngle(double a) {
  double x = a;
  while (x > math.pi / 2) {
    x -= math.pi;
  }
  while (x < -math.pi / 2) {
    x += math.pi;
  }
  return x;
}
