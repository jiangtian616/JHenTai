import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'dart:io' as io;

import 'package:jhentai/src/utils/log.dart';

/// responsible for all network and local images, depends on :
/// 1. ExtendedImage:
///   - interface of reading from network or local file
///   - memory cache for local image
///   - memory and disk cache for all network images
///   - supply network image's datasource for image_gallery_saver
/// 2. image_gallery_saver:
///   - when user has read several pages, and then begin to download this gallery,
///   it helps to save the cached images first rather than re-download
///
/// this class accept a [GalleryImage] parameter, which indicates whether this image has been downloaded
/// or is being downloaded, and if so, it'll supplies its file path.
///
/// when user begins to download a gallery, all images's meta-data are parsed into [GalleryImage] and stored into disk
/// by get_storage.

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);

class EHImage extends StatelessWidget {
  final GalleryImage galleryImage;
  final LoadingProgressWidgetBuilder? loadingWidgetBuilder;
  final FailedWidgetBuilder? failedWidgetBuilder;
  final bool adaptive;
  final BoxFit? fit;
  final ExtendedImageMode mode;
  final InitGestureConfigHandler? initGestureConfigHandler;
  final CancellationToken? cancelToken;

  /// used to listen progress when loading network image

  const EHImage({
    Key? key,
    required this.galleryImage,
    this.loadingWidgetBuilder,
    this.failedWidgetBuilder,
    this.adaptive = false,
    this.fit,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.cancelToken,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (galleryImage.status != ImageStatus.none) {
      return ExtendedImage.file(
        io.File(galleryImage.path!),
        height: adaptive ? null : galleryImage.height,
        width: adaptive ? null : galleryImage.width,
        fit: fit,
        mode: mode,
      );
    }

    return GestureDetector(
      child: ExtendedImage.network(
        galleryImage.url,
        height: adaptive ? null : galleryImage.height,
        width: adaptive ? null : galleryImage.width,
        fit: fit,
        mode: mode,
        initGestureConfigHandler: initGestureConfigHandler,
        cancelToken: cancelToken,
        handleLoadingProgress: true,
        loadStateChanged: (ExtendedImageState state) {
          if (state.extendedImageLoadState == LoadState.loading && loadingWidgetBuilder != null) {
            if (state.loadingProgress == null) {
              return loadingWidgetBuilder!(0.01);
            }

            int cur = state.loadingProgress!.cumulativeBytesLoaded;
            int? total = state.extendedImageInfo?.sizeBytes;
            int? compressed = state.loadingProgress!.expectedTotalBytes;
            return loadingWidgetBuilder!(cur / (compressed ?? total ?? cur * 100));
          }

          if (state.extendedImageLoadState == LoadState.failed) {
            return failedWidgetBuilder == null ? null : failedWidgetBuilder!(state);
          }
          return null;
        },
      ),
    );
  }
}
