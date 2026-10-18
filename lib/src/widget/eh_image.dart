import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';

// ignore: implementation_imports
import 'package:extended_image_library/src/network/network_image_io.dart' as network_image_io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'dart:io' as io;

import 'dart:ui' as ui;

import '../service/gallery_download/download_path_resolver.dart';
import '../service/gallery_download/gallery_download_service.dart';

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
  final bool disableAnimation;

  /// If true, an animated image only plays its animation while it is visible in
  /// the viewport; otherwise it stays on its static first frame. This is meant
  /// for the main image of a reading page, where many off-screen images are kept
  /// alive by the scroll cache extent.
  final bool animateOnlyWhenVisible;

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
    this.disableAnimation = false,
    this.animateOnlyWhenVisible = false,
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
    this.disableAnimation = false,
    this.animateOnlyWhenVisible = false,
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
  // The gate is shared per-image across widget instances. A cached codec can
  // outlive the widget that created it (the image cache holds the completer),
  // so a per-widget gate would be left permanently paused when its widget is
  // disposed while the codec is parked on it, freezing the animation even
  // after the image scrolls back into view.
  late final EHImageAnimationGate _gate = EHImageAnimationGateRegistry.gateFor(_imageKey);

  String get _imageKey => widget.galleryImage.path ?? widget.galleryImage.url;

  @override
  void initState() {
    super.initState();
    if (widget.animateOnlyWhenVisible && !widget.disableAnimation && _canBeAnimated) {
      _startVisibilityCheck();
    }
  }

  /// Whether this image could be an animated webp/gif. Network images can't be
  /// told apart before decoding, so they are treated as potentially animated.
  bool get _canBeAnimated {
    final String? path = widget.galleryImage.path;
    if (path == null) {
      return true;
    }
    final String lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.webp') || lowerPath.endsWith('.gif');
  }

  /// Re-checks visibility after every frame while frames are being produced.
  /// Off-screen animated images are paused (and frozen on their static frame),
  /// which stops the expensive multi-frame decoding of cached-out images.
  void _startVisibilityCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bool visible = _isVisible();
      _gate.setPaused(!visible);
      _startVisibilityCheck();
    });
  }

  bool _isVisible() {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached || renderObject is! RenderBox || !renderObject.hasSize) {
      return true;
    }
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null || viewport is! RenderBox) {
      return true;
    }
    final RenderBox viewportBox = viewport as RenderBox;
    final Rect boundsInViewport = MatrixUtils.transformRect(
      renderObject.getTransformTo(viewportBox),
      renderObject.paintBounds,
    );
    return boundsInViewport.overlaps(Offset.zero & viewportBox.size);
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

    if (widget.autoLayout) {
      return LayoutBuilder(
        builder: (_, constraints) => Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          decoration: BoxDecoration(color: widget.containerColor, borderRadius: widget.borderRadius),
          child: child,
        ),
      );
    }

    return Container(
      height: widget.containerHeight,
      width: widget.containerWidth,
      decoration: BoxDecoration(color: widget.containerColor, borderRadius: widget.borderRadius),
      child: child,
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    final String url = _replaceEXUrl(widget.galleryImage.url);
    final bool useGate = widget.animateOnlyWhenVisible && !widget.disableAnimation;

    return ExtendedImage(
      image: ExtendedResizeImage.resizeIfNeeded(
        provider: useGate
            ? _GateExtendedNetworkImageProvider(url, cache: true, printError: kDebugMode, gate: _gate)
            : ExtendedNetworkImageProvider(url, cache: true, printError: kDebugMode),
        maxBytes: widget.maxBytes,
      ),
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
                ? widget.loadingProgressWidgetBuilder!.call(_computeLoadingProgress(state.loadingProgress, state.extendedImageInfo))
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(child: const Icon(Icons.sentiment_very_dissatisfied), onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = widget.completedWidgetBuilder?.call(state) ?? _buildExtendedRawImage(state);

            if (widget.borderRadius != BorderRadius.zero) {
              child = ClipRRect(child: child, borderRadius: widget.borderRadius);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(child: child, extendedImageSlidePageState: state.slidePageState);
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(boxShadow: widget.shadows, borderRadius: widget.borderRadius),
                child: child,
              ),
            );

            return widget.forceFadeIn || !state.wasSynchronouslyLoaded ? child.fadeIn() : child;
        }
      },
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (widget.galleryImage.downloadStatus == DownloadStatus.paused) {
      return widget.pausedWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (widget.galleryImage.downloadStatus == DownloadStatus.downloading) {
      return widget.downloadingWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    final io.File file = io.File(DownloadPathResolver.computeImageDownloadAbsolutePathFromRelativePath(widget.galleryImage.path!));
    final String lowerPath = widget.galleryImage.path!.toLowerCase();
    final bool isAnimatedFile = lowerPath.endsWith('.webp') || lowerPath.endsWith('.gif');

    final ImageProvider provider;
    if (widget.disableAnimation && isAnimatedFile) {
      provider = _SingleFrameExtendedFileImageProvider(file);
    } else if (widget.animateOnlyWhenVisible && !widget.disableAnimation && isAnimatedFile) {
      provider = _GateExtendedFileImageProvider(file, _gate);
    } else {
      provider = ExtendedFileImageProvider(file);
    }

    return ExtendedImage(
      image: ExtendedResizeImage.resizeIfNeeded(provider: provider, maxBytes: widget.maxBytes),
      fit: widget.fit,
      height: widget.containerHeight,
      width: widget.containerWidth,
      enableLoadState: widget.loadingWidgetBuilder != null || widget.failedWidgetBuilder != null || widget.completedWidgetBuilder != null,
      enableSlideOutPage: widget.enableSlideOutPage,
      borderRadius: widget.borderRadius,
      shape: BoxShape.rectangle,
      clearMemoryCacheWhenDispose: widget.clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return widget.loadingWidgetBuilder != null ? widget.loadingWidgetBuilder!.call() : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(child: const Icon(Icons.sentiment_very_dissatisfied), onTap: state.reLoadImage),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = widget.completedWidgetBuilder?.call(state) ?? _buildExtendedRawImage(state);

            child = ClipRRect(child: child, borderRadius: widget.borderRadius);

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(child: child, extendedImageSlidePageState: state.slidePageState);
            }

            return FadeIn(
              child: Center(
                child: Container(
                  decoration: BoxDecoration(boxShadow: widget.shadows, borderRadius: widget.borderRadius),
                  child: child,
                ),
              ),
            );
        }
      },
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
    if (host != 's.exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: 'ehgt.org');
    return newUri.toString();
  }

  Widget _buildExtendedRawImage(ExtendedImageState state) {
    FittedSizes fittedSizes = applyBoxFit(
      widget.fit,
      Size(state.extendedImageInfo!.image.width.toDouble(), state.extendedImageInfo!.image.height.toDouble()),
      Size(widget.containerWidth ?? double.infinity, widget.containerHeight ?? double.infinity),
    );

    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      height: fittedSizes.destination.height == 0 ? null : fittedSizes.destination.height,
      width: fittedSizes.destination.width == 0 ? null : fittedSizes.destination.width,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: widget.fit,
    );
  }
}

/// A live switch shared between an animated image's codec and its visibility
/// checker. When [paused] is true, the codec stops decoding new frames, so the
/// animation freezes on the current frame until it is resumed.
class EHImageAnimationGate {
  bool _paused = false;
  Completer<void>? _resumeCompleter;

  bool get paused => _paused;

  void setPaused(bool value) {
    if (_paused == value) {
      return;
    }
    _paused = value;
    if (!value) {
      _resumeCompleter?.complete();
      _resumeCompleter = null;
    }
  }

  /// Completes once the gate is no longer paused.
  Future<void> whenResumed() {
    if (!_paused) {
      return Future.value();
    }
    return (_resumeCompleter ??= Completer<void>()).future;
  }
}

/// Maps a stable image key (local path or network url) to its shared animation
/// gate. A codec can outlive the EHImage widget that created it, so every
/// widget for the same cached image must control the same gate; otherwise a
/// gate whose widget was disposed stays paused forever and freezes the cached
/// animation.
///
/// Values are [WeakReference]s so a gate lives exactly as long as something
/// still uses it (a codec or a widget holds it strongly) and is collected once
/// nothing does. Stale entries are pruned periodically to keep the map bounded.
class EHImageAnimationGateRegistry {
  static final Map<String, WeakReference<EHImageAnimationGate>> _gates = {};
  static int _newEntriesSincePrune = 0;

  static EHImageAnimationGate gateFor(String key) {
    final gate = _gates[key]?.target;
    if (gate != null) {
      return gate;
    }
    final newGate = EHImageAnimationGate();
    _gates[key] = WeakReference(newGate);
    if (++_newEntriesSincePrune >= 256) {
      _newEntriesSincePrune = 0;
      _gates.removeWhere((_, weak) => weak.target == null);
    }
    return newGate;
  }

  /// Called when the reading page is torn down. Unpauses every gate first so a
  /// codec parked on it is not stuck forever, then forgets them all. Cached
  /// codecs that outlive the page keep their (now unpaused) gate, so re-entering
  /// the gallery can't freeze; those images simply animate without off-screen
  /// pausing until they are evicted and reloaded.
  static void clear() {
    for (final WeakReference<EHImageAnimationGate> weak in _gates.values) {
      weak.target?.setPaused(false);
    }
    _gates.clear();
    _newEntriesSincePrune = 0;
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
  Future<ui.Codec> instantiateImageCodec(Uint8List data, ImageDecoderCallback decode) async {
    final ui.Codec codec = await super.instantiateImageCodec(data, decode);
    if (codec.frameCount > 1) {
      return _SingleFrameCodec(codec);
    }
    return codec;
  }
}

/// Wraps a multi-frame codec so that [getNextFrame] blocks while the gate is
/// paused. The first frame is always delivered, so a paused image still shows
/// its static first frame. Pausing between [getNextFrame] calls doesn't advance
/// the repetition budget, so the animation resumes exactly where it left off.
class _PausableCodec implements ui.Codec {
  _PausableCodec(this._inner, this._gate);

  final ui.Codec _inner;
  final EHImageAnimationGate _gate;
  bool _firstFrameDelivered = false;
  bool _disposed = false;

  /// Never completes. Returned once the codec has been disposed so the image
  /// completer's decode loop just stays parked instead of throwing on a
  /// disposed native codec (which would surface in the debug console).
  static final Future<ui.FrameInfo> _neverCompletes = Completer<ui.FrameInfo>().future;

  @override
  int get frameCount => _inner.frameCount;

  @override
  int get repetitionCount => _inner.repetitionCount;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    if (_disposed) {
      return _neverCompletes;
    }
    if (!_firstFrameDelivered) {
      _firstFrameDelivered = true;
      return _inner.getNextFrame();
    }
    if (_gate.paused) {
      await _gate.whenResumed();
    }
    if (_disposed) {
      return _neverCompletes;
    }
    return _inner.getNextFrame();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _inner.dispose();
  }
}

class _GateExtendedFileImageProvider extends ExtendedFileImageProvider {
  // ignore: prefer_const_constructors_in_immutables
  _GateExtendedFileImageProvider(super.file, this.gate);

  final EHImageAnimationGate gate;

  @override
  Future<ui.Codec> instantiateImageCodec(Uint8List data, ImageDecoderCallback decode) async {
    final ui.Codec codec = await super.instantiateImageCodec(data, decode);
    return codec.frameCount > 1 ? _PausableCodec(codec, gate) : codec;
  }
}

class _GateExtendedNetworkImageProvider extends network_image_io.ExtendedNetworkImageProvider {
  _GateExtendedNetworkImageProvider(super.url, {super.cache, super.printError, required this.gate});

  final EHImageAnimationGate gate;

  @override
  Future<ui.Codec> instantiateImageCodec(Uint8List data, ImageDecoderCallback decode) async {
    final ui.Codec codec = await super.instantiateImageCodec(data, decode);
    return codec.frameCount > 1 ? _PausableCodec(codec, gate) : codec;
  }
}
