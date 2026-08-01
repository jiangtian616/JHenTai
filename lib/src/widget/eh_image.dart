import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../service/gallery_download_service.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();
typedef LoadingWidgetBuilder = Widget Function();
typedef CompletedWidgetBuilder = Widget? Function(ExtendedImageState state);

class EHImage extends StatefulWidget {
  final GalleryImage galleryImage;
  final bool autoLayout;
  final double? containerHeight;
  final double? containerWidth;
  final Color? containerColor;
  final BoxFit fit;
  final bool enableSlideOutPage;
  final BorderRadius borderRadius;
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
  final bool disableGifAnimation;

  /// When true, animated images (webp / gif) only play while visible on
  /// screen. Off-screen (e.g. preloaded) animated images render their first
  /// frame only, which mirrors OpenComic's IntersectionObserver lazy-decode
  /// strategy and reduces decode cost / memory pressure when the read page
  /// preloads many images. When false, behavior falls back to
  /// [disableGifAnimation] (all-or-nothing).
  final bool playAnimation;

  const EHImage({
    Key? key,
    required this.galleryImage,
    this.autoLayout = false,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.enableSlideOutPage = false,
    this.borderRadius = BorderRadius.zero,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.disableGifAnimation = false,
    this.playAnimation = false,
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
    this.borderRadius = BorderRadius.zero,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.disableGifAnimation = false,
    this.playAnimation = false,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  }) : super(key: key);

  @override
  State<EHImage> createState() => _EHImageState();
}

class _EHImageState extends State<EHImage> {
  /// Minimum visible fraction required to start playing animations. A small
  /// non-zero value avoids floating-point edge cases while still treating any
  /// partially visible image as "visible".
  static const double _visibilityThreshold = 0.01;

  bool _isVisible = false;

  /// Only webp and gif files can contain animations among the formats we
  /// handle. Visibility tracking is gated on this to avoid overhead for the
  /// common case of static jpg/png images.
  ///
  /// For local images [GalleryImage.path] carries the file extension. For
  /// online images [GalleryImage.path] is null, so we fall back to the URL
  /// path — EH image URLs end with the file extension (.jpg/.png/.webp/.gif).
  bool get _isPotentiallyAnimated {
    final path = widget.galleryImage.path?.toLowerCase() ?? '';
    if (path.endsWith('.webp') || path.endsWith('.gif')) {
      return true;
    }
    final urlPath =
        Uri.tryParse(widget.galleryImage.url)?.path.toLowerCase() ?? '';
    return urlPath.endsWith('.webp') || urlPath.endsWith('.gif');
  }

  /// Whether visibility tracking should be active. Requires [widget.playAnimation],
  /// a potentially animated file, and not [widget.disableGifAnimation] (which
  /// already forces single-frame rendering for all cases).
  bool get _needsVisibilityTracking =>
      widget.playAnimation &&
      !widget.disableGifAnimation &&
      _isPotentiallyAnimated;

  /// Returns true when the image should be rendered as a single frame.
  ///
  /// Priority:
  /// 1. Non-animated formats always render normally (false).
  /// 2. [widget.disableGifAnimation] forces single-frame (existing behavior).
  /// 3. [widget.playAnimation] enables visibility-aware control: visible
  ///    images play, off-screen images show the first frame only.
  /// 4. Otherwise, animations play (existing default).
  bool get _shouldUseSingleFrame {
    if (!_isPotentiallyAnimated) {
      return false;
    }
    if (widget.disableGifAnimation) {
      return true;
    }
    if (widget.playAnimation) {
      return !_isVisible;
    }
    return false;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final newVisible = info.visibleFraction > _visibilityThreshold;
    if (newVisible != _isVisible) {
      setState(() {
        _isVisible = newVisible;
      });
    }
  }

  Key _buildVisibilityDetectorKey() {
    final id = widget.galleryImage.path ?? widget.galleryImage.url;
    return ValueKey<String>('eh_image_visibility::$id');
  }

  @override
  Widget build(BuildContext context) {
    Widget child = advancedSetting.inNoImageMode.isTrue
        ? const SizedBox()
        : widget.galleryImage.path == null
            ? buildNetworkImage(context)
            : buildFileImage(context);

    if (widget.heroTag != null && styleSetting.isInMobileLayout) {
      child = Hero(tag: widget.heroTag!, child: child);
    }

    if (_needsVisibilityTracking) {
      child = VisibilityDetector(
        key: _buildVisibilityDetectorKey(),
        onVisibilityChanged: _onVisibilityChanged,
        child: child,
      );
    }

    if (widget.autoLayout) {
      return LayoutBuilder(
        builder: (_, constraints) => Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
              color: widget.containerColor, borderRadius: widget.borderRadius),
          child: child,
        ),
      );
    }

    return Container(
      height: widget.containerHeight,
      width: widget.containerWidth,
      decoration: BoxDecoration(
          color: widget.containerColor, borderRadius: widget.borderRadius),
      child: child,
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    final String url = _replaceEXUrl(widget.galleryImage.url);
    final bool shouldRenderSingleFrame = _shouldUseSingleFrame;

    /// Off-screen preloaded animated images decode only their first frame via
    /// [_SingleFrameExtendedNetworkImageProvider]; visible / force-played
    /// images use the full animated codec. Mirrors [buildFileImage].
    final ImageProvider provider;
    if (shouldRenderSingleFrame) {
      provider = _SingleFrameExtendedNetworkImageProvider(
        url,
        cache: true,
        printError: kDebugMode,
      );
    } else {
      provider = ExtendedNetworkImageProvider(
        url,
        cache: true,
        printError: kDebugMode,
      );
    }

    return ExtendedImage(
      image: ExtendedResizeImage.resizeIfNeeded(
          provider: provider, maxBytes: widget.maxBytes),
      fit: widget.fit,
      height: widget.containerHeight,
      width: widget.containerWidth,
      enableLoadState: true,
      handleLoadingProgress: widget.loadingProgressWidgetBuilder != null,
      enableSlideOutPage: widget.enableSlideOutPage,
      clearMemoryCacheWhenDispose: widget.clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return widget.loadingProgressWidgetBuilder != null
                ? widget.loadingProgressWidgetBuilder!.call(
                    _computeLoadingProgress(
                        state.loadingProgress, state.extendedImageInfo))
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                      child: const Icon(Icons.sentiment_very_dissatisfied),
                      onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = widget.completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            if (widget.borderRadius != BorderRadius.zero) {
              child =
                  ClipRRect(child: child, borderRadius: widget.borderRadius);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                  child: child,
                  extendedImageSlidePageState: state.slidePageState);
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(
                    boxShadow: widget.shadows,
                    borderRadius: widget.borderRadius),
                child: child,
              ),
            );

            return widget.forceFadeIn || !state.wasSynchronouslyLoaded
                ? child.fadeIn()
                : child;
        }
      },
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (widget.galleryImage.downloadStatus == DownloadStatus.paused) {
      return widget.pausedWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.galleryImage.downloadStatus == DownloadStatus.downloading) {
      return widget.downloadingWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    final io.File file = io.File(
        GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
            widget.galleryImage.path!));
    final bool shouldRenderSingleFrame = _shouldUseSingleFrame;

    final ImageProvider provider = shouldRenderSingleFrame
        ? _SingleFrameExtendedFileImageProvider(file)
        : ExtendedFileImageProvider(file);

    return ExtendedImage(
      image: ExtendedResizeImage.resizeIfNeeded(
          provider: provider, maxBytes: widget.maxBytes),
      fit: widget.fit,
      height: widget.containerHeight,
      width: widget.containerWidth,
      enableLoadState: widget.loadingWidgetBuilder != null ||
          widget.failedWidgetBuilder != null ||
          widget.completedWidgetBuilder != null,
      enableSlideOutPage: widget.enableSlideOutPage,
      borderRadius: widget.borderRadius,
      shape: BoxShape.rectangle,
      clearMemoryCacheWhenDispose: widget.clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return widget.loadingWidgetBuilder != null
                ? widget.loadingWidgetBuilder!.call()
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                      child: const Icon(Icons.sentiment_very_dissatisfied),
                      onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = widget.completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            child = ClipRRect(child: child, borderRadius: widget.borderRadius);

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                  child: child,
                  extendedImageSlidePageState: state.slidePageState);
            }

            return FadeIn(
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                      boxShadow: widget.shadows,
                      borderRadius: widget.borderRadius),
                  child: child,
                ),
              ),
            );
        }
      },
      filterQuality: FilterQuality.medium,
    );
  }

  double _computeLoadingProgress(
      ImageChunkEvent? loadingProgress, ImageInfo? extendedImageInfo) {
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
    if (host != 's.exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: 'ehgt.org');
    return newUri.toString();
  }

  Widget _buildExtendedRawImage(ExtendedImageState state) {
    FittedSizes fittedSizes = applyBoxFit(
      widget.fit,
      Size(state.extendedImageInfo!.image.width.toDouble(),
          state.extendedImageInfo!.image.height.toDouble()),
      Size(widget.containerWidth ?? double.infinity,
          widget.containerHeight ?? double.infinity),
    );

    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      height: fittedSizes.destination.height == 0
          ? null
          : fittedSizes.destination.height,
      width: fittedSizes.destination.width == 0
          ? null
          : fittedSizes.destination.width,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: widget.fit,
    );
  }
}

class _SingleFrameCodec implements ui.Codec {
  final ui.Codec _inner;

  _SingleFrameCodec(this._inner);

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() => _inner.getNextFrame();

  @override
  void dispose() => _inner.dispose();
}

class _SingleFrameExtendedFileImageProvider extends ExtendedFileImageProvider {
  const _SingleFrameExtendedFileImageProvider(super.file);

  @override
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, ImageDecoderCallback decode) async {
    final ui.Codec codec = await super.instantiateImageCodec(data, decode);
    if (codec.frameCount > 1) {
      return _SingleFrameCodec(codec);
    }
    return codec;
  }
}

/// [ExtendedNetworkImageProvider] equivalent that decodes only the first frame
/// of animated webp/gif images. Used for off-screen preloaded online images so
/// that the read page doesn't pay the decode / memory cost of keeping many
/// full animations alive simultaneously.
///
/// The public [ExtendedNetworkImageProvider] is abstract with a factory
/// constructor, so it cannot be subclassed directly with a simple
/// [instantiateImageCodec] override (unlike [ExtendedFileImageProvider]). We
/// instead compose: an internal delegate created via the factory handles disk
/// caching and HTTP fetching ([getNetworkImageData]), and we decode the raw
/// bytes ourselves via [instantiateImageCodec] so multi-frame codecs can be
/// wrapped with [_SingleFrameCodec].
class _SingleFrameExtendedNetworkImageProvider
    extends ImageProvider<_SingleFrameExtendedNetworkImageProvider>
    with ExtendedImageProvider<_SingleFrameExtendedNetworkImageProvider> {
  _SingleFrameExtendedNetworkImageProvider(
    this.url, {
    this.cache = true,
    this.printError = true,
  });

  final String url;
  final bool cache;
  final bool printError;
  @override
  final bool cacheRawData = false;
  @override
  final String? imageCacheName = null;

  /// Delegate that owns the disk cache + HTTP fetching. Lazily created so we
  /// don't pay for it when the provider is only used as a cache key.
  ExtendedNetworkImageProvider? _fetcher;
  ExtendedNetworkImageProvider get _delegate => _fetcher ??=
      ExtendedNetworkImageProvider(url, cache: cache, printError: printError);

  @override
  Future<_SingleFrameExtendedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<_SingleFrameExtendedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_SingleFrameExtendedNetworkImageProvider key,
      ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      scale: 1.0,
      chunkEvents: chunkEvents.stream,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<_SingleFrameExtendedNetworkImageProvider>(
            'Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _SingleFrameExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    final Uint8List? data =
        await key._delegate.getNetworkImageData(chunkEvents: chunkEvents);
    if (data == null || data.lengthInBytes == 0) {
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }
    return await instantiateImageCodec(data, decode);
  }

  @override
  Future<ui.Codec> instantiateImageCodec(
      Uint8List data, ImageDecoderCallback decode) async {
    final ui.Codec codec = await super.instantiateImageCodec(data, decode);
    if (codec.frameCount > 1) {
      return _SingleFrameCodec(codec);
    }
    return codec;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _SingleFrameExtendedNetworkImageProvider &&
        url == other.url &&
        cache == other.cache &&
        printError == other.printError;
  }

  @override
  int get hashCode => Object.hash(url, cache, printError);

  @override
  String toString() => '$runtimeType("$url")';
}
