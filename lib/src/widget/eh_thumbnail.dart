import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';

import '../model/gallery_image.dart';
import 'eh_image.dart';

class EHThumbnail extends StatelessWidget {
  final GalleryThumbnail thumbnail;
  final double? containerHeight;
  final double? containerWidth;
  final BorderRadius borderRadius;

  const EHThumbnail({
    Key? key,
    required this.thumbnail,
    this.containerHeight,
    this.containerWidth,
    this.borderRadius = BorderRadius.zero,
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
      /// single large thumbnails rarely need more than 512KB decoded
      maxBytes: 512 * 1024,
    );
  }

  Widget _buildSmallThumbnail() {
    return EHImage(
      galleryImage: GalleryImage(url: thumbnail.thumbUrl),
      containerHeight: containerHeight,
      containerWidth: containerWidth,
      borderRadius: borderRadius,
      /// The sprite strip is one row of ten thumbnails; decoding it at native
      /// resolution costs ~10x the memory of a single thumbnail. [maxBytes]
      /// caps the decode budget (no cacheWidth/cacheHeight: those would change
      /// the delivered dimensions and break the sourceRect crop below).
      maxBytes: 256 * 1024,
      completedWidgetBuilder: (ExtendedImageState state) {
        FittedSizes fittedSizes = applyBoxFit(
          BoxFit.contain,
          Size(thumbnail.thumbWidth!, thumbnail.thumbHeight!),
          Size(containerWidth ?? double.infinity, containerHeight ?? double.infinity),
        );

        /// crop image because raw image consists of 10 thumbnails in row.
        /// sourceRect lives in the delivered image's pixel space: when the
        /// byte cap forces a scaled decode the strip shrinks uniformly, so
        /// scale the original crop coordinates by the delivered/thumbnail
        /// height ratio (the strip is exactly one thumbnail tall). When no
        /// resize happens the ratio is 1 and the rect is unchanged.
        final int? deliveredHeight = state.extendedImageInfo?.image?.height;
        final double scale = deliveredHeight == null
            ? 1
            : deliveredHeight / thumbnail.thumbHeight!;
        return ExtendedRawImage(
          image: state.extendedImageInfo?.image,
          fit: BoxFit.fill,
          height: fittedSizes.destination.height,
          width: fittedSizes.destination.width,
          sourceRect: Rect.fromLTRB(
            thumbnail.offSet! * scale,
            0,
            (thumbnail.offSet! + thumbnail.thumbWidth!) * scale,
            thumbnail.thumbHeight! * scale,
          ),
        );
      },
    );
  }
}
