import 'package:flutter/material.dart';

/// Layout rules for the reader's bottom thumbnail strip.
class ReaderThumbnailLayout {
  const ReaderThumbnailLayout._();

  static const double defaultHeight = 120;
  static const double defaultWidth = 80;

  static Size sizeFor({
    required double height,
    double? imageWidth,
    double? imageHeight,
  }) {
    final bool hasRatio =
        imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0;
    final double width =
        hasRatio
            ? height * imageWidth / imageHeight
            : height * defaultWidth / defaultHeight;
    return Size(width, height);
  }
}

/// A fixed-height thumbnail slot whose width follows the source image ratio.
class ReaderThumbnailFrame extends StatelessWidget {
  const ReaderThumbnailFrame({
    super.key,
    required this.height,
    required this.image,
    this.imageWidth,
    this.imageHeight,
  });

  final double height;
  final double? imageWidth;
  final double? imageHeight;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    final Size size = ReaderThumbnailLayout.sizeFor(
      height: height,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    return SizedBox(width: size.width, height: size.height, child: image);
  }
}
