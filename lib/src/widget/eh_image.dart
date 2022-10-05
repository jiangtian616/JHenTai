import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../service/gallery_download_service.dart';
import '../setting/network_setting.dart';
import '../setting/path_setting.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef CompletedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();

class EHImage extends StatelessWidget {
  final GalleryImage galleryImage;
  final double? containerHeight;
  final double? containerWidth;
  final Color? containerColor;
  final BoxFit fit;
  final ExtendedImageMode mode;
  final InitGestureConfigHandler? initGestureConfigHandler;
  final bool enableSlideOutPage;
  final BorderRadius? borderRadius;
  final Object? heroTag;
  final bool clearMemoryCacheWhenDispose;
  final List<BoxShadow>? shadows;
  final LoadingProgressWidgetBuilder? loadingWidgetBuilder;
  final FailedWidgetBuilder? failedWidgetBuilder;
  final DownloadingWidgetBuilder? downloadingWidgetBuilder;
  final PausedWidgetBuilder? pausedWidgetBuilder;
  final CompletedWidgetBuilder? completedWidgetBuilder;

  const EHImage.file({
    Key? key,
    required this.galleryImage,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.enableSlideOutPage = false,
    this.borderRadius,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.completedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.failedWidgetBuilder,
  }) : super(key: key);

  const EHImage.network({
    Key? key,
    required this.galleryImage,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.enableSlideOutPage = false,
    this.borderRadius,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.loadingWidgetBuilder,
    this.failedWidgetBuilder,
    this.completedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child = galleryImage.path == null ? buildNetworkImage() : buildFileImage();
    if (heroTag != null && StyleSetting.isInMobileLayout) {
      child = Hero(tag: heroTag!, child: child);
    }

    if (containerHeight == null && containerWidth == null && containerColor == null && shadows == null) {
      return child;
    }

    FittedSizes fittedSizes = applyBoxFit(
      fit,
      Size(galleryImage.width, galleryImage.height),
      Size(containerWidth ?? double.infinity, containerHeight ?? double.infinity),
    );

    /// Outer container for layout and background color
    return Container(
      height: containerHeight,
      width: containerWidth,
      decoration: BoxDecoration(color: containerColor, borderRadius: borderRadius),
      child: Center(
        /// inner container for shadows, whose size is the same as image
        child: Container(
          height: fittedSizes.destination.height,
          width: fittedSizes.destination.width,
          decoration: BoxDecoration(boxShadow: shadows),
          child: child,
        ),
      ),
    );
  }

  Widget buildNetworkImage() {
    return ExtendedImage.network(
      _replaceEXUrl(galleryImage.url),
      fit: fit,
      mode: mode,
      height: containerHeight,
      width: containerWidth,
      initGestureConfigHandler: initGestureConfigHandler,
      handleLoadingProgress: loadingWidgetBuilder != null,
      printError: false,
      enableSlideOutPage: enableSlideOutPage,
      // headers: _cookieHeaders(galleryImage.url),
      borderRadius: borderRadius,
      shape: borderRadius != null ? BoxShape.rectangle : null,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return loadingWidgetBuilder != null
                ? loadingWidgetBuilder!.call(
                    _computeLoadingProgress(state.loadingProgress, state.extendedImageInfo),
                  )
                : Center(child: UIConfig.loadingAnimation);
          case LoadState.failed:
            return failedWidgetBuilder?.call(state);
          case LoadState.completed:
            return state.wasSynchronouslyLoaded
                ? completedWidgetBuilder?.call(state) ?? _getCompletedWidget(state)
                : FadeIn(
                    child: completedWidgetBuilder?.call(state) ?? _getCompletedWidget(state),
                  );
        }
      },
    );
  }

  Widget buildFileImage() {
    if (galleryImage.downloadStatus == DownloadStatus.paused) {
      return pausedWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (galleryImage.downloadStatus == DownloadStatus.downloading) {
      return downloadingWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    return ExtendedImage.file(
      io.File(GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(galleryImage.path!)),
      fit: fit,
      mode: mode,
      height: containerHeight,
      width: containerWidth,
      enableLoadState: true,
      enableSlideOutPage: enableSlideOutPage,
      borderRadius: borderRadius,
      shape: borderRadius != null ? BoxShape.rectangle : null,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        if (state.extendedImageLoadState == LoadState.completed) {
          return FadeIn(
            child: completedWidgetBuilder?.call(state) ?? _getCompletedWidget(state),
          );
        }
        return null;
      },
    );
  }

  double _computeLoadingProgress(ImageChunkEvent? loadingProgress, ImageInfo? extendedImageInfo) {
    if (loadingProgress == null) {
      return 0.01;
    }

    int cur = loadingProgress.cumulativeBytesLoaded;
    int? total = extendedImageInfo?.sizeBytes;
    int? compressed = loadingProgress.expectedTotalBytes;
    return cur / (compressed ?? total ?? cur * 100);
  }

  /// replace image host: exhentai.org -> ehgt.org
  String _replaceEXUrl(String url) {
    Uri rawUri = Uri.parse(url);
    String host = rawUri.host;
    if (host != 'exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: 'ehgt.org');
    return newUri.toString();
  }

  /// replace image host: exhentai.org -> ${exHentaiIP}
  String _replaceEXUrlIfEnableDomainFronting(String url) {
    if (NetworkSetting.enableDomainFronting.isFalse) {
      return url;
    }

    Uri rawUri = Uri.parse(url);
    String host = rawUri.host;
    if (host != 'exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: NetworkSetting.exHentaiIP.value);
    return newUri.toString();
  }

  Map<String, String>? _cookieHeaders(String url) {
    Uri rawUri = Uri.parse(url);
    String host = rawUri.host;

    return {'Cookie': EHCookieManager.userCookies, 'host': host};
  }

  /// copied from ExtendedImage
  Widget _getCompletedWidget(ExtendedImageState state) {
    if (mode == ExtendedImageMode.gesture) {
      return ExtendedImageGesture(state);
    }
    if (mode == ExtendedImageMode.editor) {
      return ExtendedImageEditor(extendedImageState: state);
    }
    return _buildExtendedRawImage(state);
  }

  /// copied from ExtendedImage
  Widget _buildExtendedRawImage(ExtendedImageState state) {
    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: fit,
      alignment: Alignment.center,
      repeat: ImageRepeat.noRepeat,
      matchTextDirection: false,
      isAntiAlias: false,
      filterQuality: FilterQuality.low,
    );
  }
}
