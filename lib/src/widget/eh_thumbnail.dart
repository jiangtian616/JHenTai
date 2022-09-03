import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';

import '../model/gallery_image.dart';
import 'eh_image.dart';

class EHThumbnail extends StatelessWidget {
  final GalleryThumbnail thumbnail;
  final double? containerHeight;
  final double? containerWidth;

  final GalleryImage? image;

  const EHThumbnail({
    Key? key,
    required this.thumbnail,
    this.containerHeight,
    this.containerWidth,
    this.image,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return image?.downloadStatus == DownloadStatus.downloaded
        ? _buildThumbnailByLocalImage()
        : thumbnail.isLarge
            ? _buildLargeThumbnail()
            : _buildSmallThumbnail();
  }

  Widget _buildThumbnailByLocalImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: EHImage.file(
        galleryImage: image!,
        completedWidgetBuilder: (ExtendedImageState state) => ExtendedRawImage(image: state.extendedImageInfo?.image, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildLargeThumbnail() {
    return EHImage.network(
      galleryImage: GalleryImage(
        url: thumbnail.thumbUrl,
        height: thumbnail.thumbHeight!,
        width: thumbnail.thumbWidth!,
      ),
    );
  }

  Widget _buildSmallThumbnail() {
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        Size imageSize = Size(thumbnail.thumbWidth!, thumbnail.thumbHeight!);
        Size size = Size(constraints.maxWidth, constraints.maxHeight);
        FittedSizes fittedSizes = applyBoxFit(BoxFit.contain, imageSize, size);

        return EHImage.network(
          galleryImage: GalleryImage(url: thumbnail.thumbUrl, height: thumbnail.thumbWidth!, width: thumbnail.thumbHeight!),
          borderRadius: BorderRadius.circular(8),
          completedWidgetBuilder: (ExtendedImageState state) {
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
      },
    );
  }
}
