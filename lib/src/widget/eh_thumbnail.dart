import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';

import '../model/gallery_image.dart';
import 'eh_image.dart';

class EHThumbnail extends StatelessWidget {
  final GalleryThumbnail thumbnail;
  final double? containerHeight;
  final double? containerWidth;
  final BorderRadius? borderRadius;

  const EHThumbnail({
    Key? key,
    required this.thumbnail,
    this.containerHeight,
    this.containerWidth,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return thumbnail.isLarge ? _buildLargeThumbnail() : _buildSmallThumbnail();
  }

  Widget _buildLargeThumbnail() {
    return EHImage(
      galleryImage: GalleryImage(url: thumbnail.thumbUrl),
      containerHeight: containerHeight,
      containerWidth: containerWidth,
      borderRadius: borderRadius,
    );
  }

  Widget _buildSmallThumbnail() {
    return EHImage(
      galleryImage: GalleryImage(url: thumbnail.thumbUrl),
      containerHeight: containerHeight,
      containerWidth: containerWidth,
      borderRadius: borderRadius,
      completedWidgetBuilder: (ExtendedImageState state) {
        FittedSizes fittedSizes = applyBoxFit(
          BoxFit.contain,
          Size(thumbnail.thumbWidth!, thumbnail.thumbHeight!),
          Size(containerWidth ?? double.infinity, containerHeight ?? double.infinity),
        );

        /// crop image because raw image consists of 10 thumbnails in row
        return ExtendedRawImage(
          image: state.extendedImageInfo?.image,
          fit: BoxFit.fill,
          height: fittedSizes.destination.height,
          width: fittedSizes.destination.width,
          sourceRect: Rect.fromLTRB(
            thumbnail.offSet!,
            0,
            thumbnail.offSet! + thumbnail.thumbWidth!,
            thumbnail.thumbHeight!,
          ),
        );
      },
    );
  }
}
