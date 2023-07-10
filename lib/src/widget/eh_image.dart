import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'dart:io' as io;

import '../service/gallery_download_service.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();
typedef LoadingWidgetBuilder = Widget Function();
typedef CompletedWidgetBuilder = Widget? Function(ExtendedImageState state);

class EHImage extends StatelessWidget {
  final GalleryImage galleryImage;
  final bool autoLayout;
  final double? containerHeight;
  final double? containerWidth;
  final Color? containerColor;
  final BoxFit fit;
  final bool enableSlideOutPage;
  final BorderRadius? borderRadius;
  final Object? heroTag;
  final bool clearMemoryCacheWhenDispose;
  final List<BoxShadow>? shadows;
  final bool forceFadeIn;
  final int? maxBytes;

  final LoadingProgressWidgetBuilder? loadingProgressWidgetBuilder;
  final FailedWidgetBuilder? failedWidgetBuilder;
  final DownloadingWidgetBuilder? downloadingWidgetBuilder;
  final PausedWidgetBuilder? pausedWidgetBuilder;
  final LoadingWidgetBuilder? loadingWidgetBuilder;
  final CompletedWidgetBuilder? completedWidgetBuilder;

  const EHImage({
    Key? key,
    required this.galleryImage,
    this.autoLayout = false,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.enableSlideOutPage = false,
    this.borderRadius,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  }) : super(key: key);

  const EHImage.autoLayout({
    Key? key,
    required this.galleryImage,
    this.autoLayout = true,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.enableSlideOutPage = false,
    this.borderRadius,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child = AdvancedSetting.inNoImageMode.isTrue
        ? const SizedBox()
        : galleryImage.path == null
            ? buildNetworkImage(context)
            : buildFileImage(context);

    if (heroTag != null && StyleSetting.isInMobileLayout) {
      child = Hero(tag: heroTag!, child: child);
    }

    if (autoLayout) {
      return LayoutBuilder(
        builder: (_, constraints) => Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          decoration: BoxDecoration(color: containerColor, borderRadius: borderRadius),
          child: child,
        ),
      );
    }

    return Container(
      height: containerHeight,
      width: containerWidth,
      decoration: BoxDecoration(color: containerColor, borderRadius: borderRadius),
      child: child,
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    return ExtendedImage.network(
      _replaceEXUrl(galleryImage.url),
      fit: fit,
      height: containerHeight,
      width: containerWidth,
      handleLoadingProgress: loadingProgressWidgetBuilder != null,
      printError: false,
      enableSlideOutPage: enableSlideOutPage,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return loadingProgressWidgetBuilder != null
                ? loadingProgressWidgetBuilder!.call(_computeLoadingProgress(state.loadingProgress, state.extendedImageInfo))
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(child: const Icon(Icons.sentiment_very_dissatisfied), onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = completedWidgetBuilder?.call(state) ?? _buildExtendedRawImage(state);

            if (borderRadius != null) {
              child = ClipRRect(child: child, borderRadius: borderRadius);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(child: child, extendedImageSlidePageState: state.slidePageState);
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(boxShadow: shadows, borderRadius: borderRadius),
                child: child,
              ),
            );

            return forceFadeIn || !state.wasSynchronouslyLoaded ? child.fadeIn() : child;
        }
      },
      maxBytes: maxBytes,
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (galleryImage.downloadStatus == DownloadStatus.paused) {
      return pausedWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (galleryImage.downloadStatus == DownloadStatus.downloading) {
      return downloadingWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    return ExtendedImage.file(
      io.File(GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(galleryImage.path!)),
      fit: fit,
      height: containerHeight,
      width: containerWidth,
      enableLoadState: loadingWidgetBuilder != null || failedWidgetBuilder != null || completedWidgetBuilder != null,
      enableSlideOutPage: enableSlideOutPage,
      borderRadius: borderRadius,
      shape: borderRadius != null ? BoxShape.rectangle : null,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return loadingWidgetBuilder != null ? loadingWidgetBuilder!.call() : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(child: const Icon(Icons.sentiment_very_dissatisfied), onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = completedWidgetBuilder?.call(state) ?? _buildExtendedRawImage(state);

            if (borderRadius != null) {
              child = ClipRRect(child: child, borderRadius: borderRadius);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(child: child, extendedImageSlidePageState: state.slidePageState);
            }

            return FadeIn(
              child: Center(
                child: Container(
                  decoration: BoxDecoration(boxShadow: shadows, borderRadius: borderRadius),
                  child: child,
                ),
              ),
            );
        }
      },
      maxBytes: maxBytes,
      filterQuality: FilterQuality.medium,
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
    if (host != 's.exhentai.org' && host != 'exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: 'ehgt.org');
    return newUri.toString();
  }

  Widget _buildExtendedRawImage(ExtendedImageState state) {
    FittedSizes fittedSizes = applyBoxFit(
      fit,
      Size(state.extendedImageInfo!.image.width.toDouble(), state.extendedImageInfo!.image.height.toDouble()),
      Size(containerWidth ?? double.infinity, containerHeight ?? double.infinity),
    );

    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      height: fittedSizes.destination.height == 0 ? null : fittedSizes.destination.height,
      width: fittedSizes.destination.width == 0 ? null : fittedSizes.destination.width,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: fit,
    );
  }
}
