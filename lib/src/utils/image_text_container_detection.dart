import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../model/image_translation.dart';
import 'image_text_grouping.dart';

/// Runs the container detector in a background isolate. The payload uses only
/// sendable JSON-like values so it can be called through Flutter's `compute`.
List<Map<String, dynamic>> detectTextContainersFromBytes(
  Map<String, dynamic> payload,
) {
  final Object? rawBytes = payload['bytes'];
  final Object? rawBlocks = payload['blocks'];
  if (rawBytes is! Uint8List || rawBlocks is! List) {
    return const <Map<String, dynamic>>[];
  }
  final image.Image? decoded = image.decodeImage(rawBytes);
  if (decoded == null) {
    return const <Map<String, dynamic>>[];
  }
  final image.Image source = image.bakeOrientation(decoded);
  final List<RecognizedTextBlock> blocks = rawBlocks
      .whereType<Map>()
      .map(
        (Map block) =>
            RecognizedTextBlock.fromJson(Map<String, dynamic>.from(block)),
      )
      .toList(growable: false);
  return detectTextContainers(source, blocks)
      .map((RecognizedTextContainer container) => container.toJson())
      .toList(growable: false);
}

/// Finds enclosed, relatively uniform regions around OCR text.
///
/// This is intentionally a conservative boundary detector, not a generic
/// object segmenter. It accepts a region only when a colour-connected component
/// surrounds the OCR union and is itself bounded inside a local crop. A broad
/// black background or a character's clothing therefore falls back to the OCR
/// rectangle instead of being painted over as a fake bubble.
List<RecognizedTextContainer> detectTextContainers(
  image.Image source,
  List<RecognizedTextBlock> blocks,
) {
  if (source.width <= 0 || source.height <= 0 || blocks.isEmpty) {
    return const <RecognizedTextContainer>[];
  }
  const int maxSide = 640;
  final double scale = math.min(
    1,
    maxSide / math.max(source.width, source.height),
  );
  final int width = math.max(1, (source.width * scale).round());
  final int height = math.max(1, (source.height * scale).round());
  final image.Image raster =
      scale == 1
          ? source
          : image.copyResize(
            source,
            width: width,
            height: height,
            interpolation: image.Interpolation.linear,
          );
  final List<RecognizedTextGroup> groups = groupRecognizedTextBlocks(blocks);
  final List<RecognizedTextContainer> result = <RecognizedTextContainer>[];
  for (final RecognizedTextGroup group in groups) {
    final _ContainerCandidate? candidate = _detectGroupContainer(
      raster,
      group,
      blocks,
      scale,
    );
    if (candidate == null) {
      continue;
    }
    result.add(
      RecognizedTextContainer(
        blockIndices: group.blockIndices,
        left: candidate.left,
        top: candidate.top,
        width: candidate.right - candidate.left,
        height: candidate.bottom - candidate.top,
        confidence: candidate.confidence,
      ),
    );
  }
  return result;
}

class _ContainerCandidate {
  const _ContainerCandidate({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double confidence;
}

_ContainerCandidate? _detectGroupContainer(
  image.Image raster,
  RecognizedTextGroup group,
  List<RecognizedTextBlock> blocks,
  double scale,
) {
  final double left = group.left * scale;
  final double top = group.top * scale;
  final double right = group.right * scale;
  final double bottom = group.bottom * scale;
  final double lineSize = math.max(
    2,
    group
        .blocksOf(blocks)
        .map((RecognizedTextBlock block) {
          return math.min(block.width, block.height) * scale;
        })
        .reduce(math.max),
  );
  final int margin = math.max(6, (lineSize * 1.4).round());
  final int cropMargin = math.max(18, margin * 3);
  final int cropLeft = math.max(0, left.floor() - cropMargin);
  final int cropTop = math.max(0, top.floor() - cropMargin);
  final int cropRight = math.min(raster.width, right.ceil() + cropMargin);
  final int cropBottom = math.min(raster.height, bottom.ceil() + cropMargin);
  if (cropRight <= cropLeft || cropBottom <= cropTop) {
    return null;
  }

  final List<({int x, int y})> seeds =
      <({int x, int y})>[
        (x: ((left + right) / 2).round(), y: ((top + bottom) / 2).round()),
        (x: ((left + right) / 2).round(), y: top.round() - margin),
        (x: ((left + right) / 2).round(), y: bottom.round() + margin),
        (x: left.round() - margin, y: ((top + bottom) / 2).round()),
        (x: right.round() + margin, y: ((top + bottom) / 2).round()),
      ].where((({int x, int y}) point) {
        return point.x >= cropLeft &&
            point.x < cropRight &&
            point.y >= cropTop &&
            point.y < cropBottom;
      }).toList();
  _ContainerCandidate? best;
  for (final ({int x, int y}) seed in seeds) {
    final _FloodRegion? region = _floodRegion(
      raster,
      seed.x,
      seed.y,
      cropLeft,
      cropTop,
      cropRight,
      cropBottom,
    );
    if (region == null) {
      continue;
    }
    final bool containsText =
        region.left <= left &&
        region.top <= top &&
        region.right >= right &&
        region.bottom >= bottom;
    if (!containsText || region.touchesCropEdge) {
      continue;
    }
    final double boxArea = math.max(
      1.0,
      (region.right - region.left).toDouble() *
          (region.bottom - region.top).toDouble(),
    );
    final double fill = region.pixels / boxArea;
    if (fill < 0.16 || region.pixels < 20) {
      continue;
    }
    final double textWidth = math.max(1, right - left);
    final double textHeight = math.max(1, bottom - top);
    if (region.right - region.left > textWidth * 7 ||
        region.bottom - region.top > textHeight * 7) {
      continue;
    }
    final double contrast = region.edgeContrast;
    if (contrast < 12) {
      continue;
    }
    final double confidence =
        (0.35 + math.min(0.35, fill * 0.45) + math.min(0.3, contrast / 100))
            .clamp(0, 1)
            .toDouble();
    final _ContainerCandidate candidate = _ContainerCandidate(
      left: region.left / scale,
      top: region.top / scale,
      right: region.right / scale,
      bottom: region.bottom / scale,
      confidence: confidence,
    );
    if (best == null || confidence > best.confidence) {
      best = candidate;
    }
  }
  return best;
}

class _FloodRegion {
  const _FloodRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.pixels,
    required this.touchesCropEdge,
    required this.edgeContrast,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final int pixels;
  final bool touchesCropEdge;
  final double edgeContrast;
}

_FloodRegion? _floodRegion(
  image.Image raster,
  int seedX,
  int seedY,
  int cropLeft,
  int cropTop,
  int cropRight,
  int cropBottom,
) {
  if (seedX < cropLeft ||
      seedX >= cropRight ||
      seedY < cropTop ||
      seedY >= cropBottom) {
    return null;
  }
  final image.Pixel seed = raster.getPixel(seedX, seedY);
  final int sr = seed.r.toInt();
  final int sg = seed.g.toInt();
  final int sb = seed.b.toInt();
  const int threshold = 34;
  final Set<int> visited = <int>{};
  final List<int> queue = <int>[seedY * raster.width + seedX];
  int cursor = 0;
  int left = seedX;
  int top = seedY;
  int right = seedX;
  int bottom = seedY;
  while (cursor < queue.length && visited.length < 180000) {
    final int packed = queue[cursor++];
    if (!visited.add(packed)) {
      continue;
    }
    final int x = packed % raster.width;
    final int y = packed ~/ raster.width;
    if (x < cropLeft || x >= cropRight || y < cropTop || y >= cropBottom) {
      continue;
    }
    final image.Pixel pixel = raster.getPixel(x, y);
    final int r = pixel.r.toInt();
    final int g = pixel.g.toInt();
    final int b = pixel.b.toInt();
    if (math.max((r - sr).abs(), math.max((g - sg).abs(), (b - sb).abs())) >
        threshold) {
      continue;
    }
    left = math.min(left, x);
    top = math.min(top, y);
    right = math.max(right, x + 1);
    bottom = math.max(bottom, y + 1);
    queue.add(y * raster.width + x + 1);
    queue.add(y * raster.width + x - 1);
    queue.add((y + 1) * raster.width + x);
    queue.add((y - 1) * raster.width + x);
  }
  final int pixels = visited.length;
  if (pixels < 20) {
    return null;
  }
  final bool touches =
      left <= cropLeft ||
      top <= cropTop ||
      right >= cropRight ||
      bottom >= cropBottom;
  final int ringStep = math.max(1, ((right - left) + (bottom - top)) ~/ 80);
  final List<double> distances = <double>[];
  for (int x = left; x < right; x += ringStep) {
    for (final int y in <int>[top - 1, bottom]) {
      if (y < cropTop || y >= cropBottom) continue;
      distances.add(
        _distance(raster.getPixel(x.clamp(0, raster.width - 1), y), sr, sg, sb),
      );
    }
  }
  for (int y = top; y < bottom; y += ringStep) {
    for (final int x in <int>[left - 1, right]) {
      if (x < cropLeft || x >= cropRight) continue;
      distances.add(
        _distance(
          raster.getPixel(x, y.clamp(0, raster.height - 1)),
          sr,
          sg,
          sb,
        ),
      );
    }
  }
  final double contrast =
      distances.isEmpty
          ? 0
          : distances.reduce((double a, double b) => a + b) / distances.length;
  return _FloodRegion(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    pixels: pixels,
    touchesCropEdge: touches,
    edgeContrast: contrast,
  );
}

double _distance(image.Pixel pixel, int r, int g, int b) => math.sqrt(
  math.pow(pixel.r.toInt() - r, 2) +
      math.pow(pixel.g.toInt() - g, 2) +
      math.pow(pixel.b.toInt() - b, 2),
);
