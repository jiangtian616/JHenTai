import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'dart:io' as io;

import 'package:jhentai/src/setting/advanced_setting.dart';


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
typedef CompletedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();

class EHImage extends StatefulWidget {
  final GalleryImage galleryImage;
  final double? containerHeight;
  final double? containerWidth;
  final LoadingProgressWidgetBuilder? loadingWidgetBuilder;
  final FailedWidgetBuilder? failedWidgetBuilder;
  final CompletedWidgetBuilder? completedWidgetBuilder;
  final DownloadingWidgetBuilder? downloadingWidgetBuilder;
  final bool adaptive;
  final BoxFit? fit;
  final ExtendedImageMode mode;
  final InitGestureConfigHandler? initGestureConfigHandler;
  final bool enableLongPressToRefresh;

  /// used to listen progress when loading network image

  const EHImage({
    Key? key,
    required this.galleryImage,
    this.containerHeight,
    this.containerWidth,
    this.loadingWidgetBuilder,
    this.failedWidgetBuilder,
    this.completedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.adaptive = false,
    this.fit,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.enableLongPressToRefresh = false,
  }) : super(key: key);

  @override
  _EHImageState createState() => _EHImageState();
}

class _EHImageState extends State<EHImage> {
  late Key key;
  late CancellationToken cancelToken;

  @override
  void initState() {
    key = UniqueKey();
    cancelToken = CancellationToken();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.containerHeight,
      width: widget.containerWidth,
      child: () {
        if (widget.galleryImage.path != null) {
          if (widget.galleryImage.downloadStatus == DownloadStatus.downloading) {
            return widget.downloadingWidgetBuilder != null
                ? widget.downloadingWidgetBuilder!()
                : const Center(child: CircularProgressIndicator());
          }
          return ExtendedImage.file(
            io.File(widget.galleryImage.path!),
            key: key,
            height: widget.adaptive ? null : widget.galleryImage.height,
            width: widget.adaptive ? null : widget.galleryImage.width,
            fit: widget.fit,
            mode: widget.mode,
            enableLoadState: true,
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: widget.enableLongPressToRefresh ? _showReloadBottomSheet : null,
          child: ExtendedImage.network(
            _replaceUrlIfInDomainFrontingAndInEX(widget.galleryImage.url),
            key: key,
            height: widget.adaptive ? null : widget.galleryImage.height,
            width: widget.adaptive ? null : widget.galleryImage.width,
            fit: widget.fit,
            mode: widget.mode,
            initGestureConfigHandler: widget.initGestureConfigHandler,
            cancelToken: widget.enableLongPressToRefresh ? cancelToken : null,
            imageCacheName: widget.galleryImage.url,
            handleLoadingProgress: widget.loadingWidgetBuilder != null,
            loadStateChanged: (ExtendedImageState state) {
              if (state.extendedImageLoadState == LoadState.loading) {
                if (widget.loadingWidgetBuilder == null) {
                  return null;
                }
                if (state.loadingProgress == null) {
                  return widget.loadingWidgetBuilder!(0.01);
                }

                int cur = state.loadingProgress!.cumulativeBytesLoaded;
                int? total = state.extendedImageInfo?.sizeBytes;
                int? compressed = state.loadingProgress!.expectedTotalBytes;
                return widget.loadingWidgetBuilder!(cur / (compressed ?? total ?? cur * 100));
              }

              if (state.extendedImageLoadState == LoadState.failed) {
                return widget.failedWidgetBuilder == null ? null : widget.failedWidgetBuilder!(state);
              }

              return widget.completedWidgetBuilder == null ? null : widget.completedWidgetBuilder!(state);
            },
          ),
        );
      }(),
    );
  }

  void _showReloadBottomSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('reloadImage'.tr),
            onPressed: () async {
              cancelToken.cancel();
              await clearDiskCachedImage(widget.galleryImage.url);
              clearMemoryImageCache(widget.galleryImage.url);
              setState(() {
                /// lead to rebuilding
                key = UniqueKey();
                cancelToken = CancellationToken();
              });
              Get.back();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: Get.back,
        ),
      ),
    );
  }

  /// replace image host: exhentai.org -> ehgt.org
  String _replaceUrlIfInDomainFrontingAndInEX(String url) {
    if (AdvancedSetting.enableDomainFronting.isFalse) {
      return url;
    }
    Uri rawUri = Uri.parse(url);
    String host = rawUri.host;
    if (host != 'exhentai.org') {
      return url;
    }

    /// thumbnails:
    String newHost = 'ehgt.org';
    Uri newUri = rawUri.replace(host: newHost);
    return newUri.toString();
  }
}
