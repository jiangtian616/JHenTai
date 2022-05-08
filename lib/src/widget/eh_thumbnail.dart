import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';

import '../model/gallery_image.dart';
import 'eh_image.dart';

class EHThumbnail extends StatelessWidget {
  final GalleryThumbnail galleryThumbnail;
  final double? containerHeight;
  final double? containerWidth;

  const EHThumbnail({
    Key? key,
    required this.galleryThumbnail,
    this.containerHeight,
    this.containerWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return galleryThumbnail.isLarge ? _buildLargeThumbnail(galleryThumbnail) : _buildSmallThumbnail(galleryThumbnail);
  }

  Widget _buildSmallThumbnail(GalleryThumbnail thumbnail) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: containerWidth ?? double.infinity,
        maxHeight: containerHeight ?? double.infinity,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          /// there's a bug that after cropping, the image's length-width ratio remains(equal to the raw image),
          /// so choose to assign the size manually.
          Size imageSize = Size(thumbnail.thumbWidth!, thumbnail.thumbHeight!);
          Size size = Size(constraints.maxWidth, constraints.maxHeight);
          FittedSizes fittedSizes = applyBoxFit(BoxFit.contain, imageSize, size);

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: EHImage.network(
              galleryImage: GalleryImage(
                url: thumbnail.thumbUrl,
                height: fittedSizes.destination.height,
                width: fittedSizes.destination.width,
              ),
              completedWidgetBuilder: (ExtendedImageState state) {
                /// crop image because raw image consists of 10 thumbnails in row
                return ExtendedRawImage(
                  image: state.extendedImageInfo?.image,
                  fit: BoxFit.fill,
                  sourceRect: Rect.fromLTRB(
                    thumbnail.offSet!,
                    0,
                    thumbnail.offSet! + thumbnail.thumbWidth!,
                    thumbnail.thumbHeight!,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeThumbnail(GalleryThumbnail thumbnail) {
    return EHImage.network(
      containerHeight: containerHeight,
      containerWidth: containerWidth,
      galleryImage: GalleryImage(
        url: thumbnail.thumbUrl,
        height: thumbnail.thumbHeight!,
        width: thumbnail.thumbWidth!,
      ),
    );
  }
}
