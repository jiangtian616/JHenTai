import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart' show LoadingBuilder, PhotoView;
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/src/core/photo_view_gesture_detector.dart';
import 'package:photo_view/src/photo_view_scale_state.dart';

import 'eh_page_view.dart';

/// copied from [PhotoViewGallery] to replace [PageView]
class EHPhotoViewGallery extends StatefulWidget {
  final double cacheExtent;

  const EHPhotoViewGallery({
    Key? key,
    required this.cacheExtent,
    required this.pageOptions,
    this.loadingBuilder,
    this.backgroundDecoration,
    this.wantKeepAlive = false,
    this.gaplessPlayback = false,
    this.reverse = false,
    this.pageController,
    this.onPageChanged,
    this.scaleStateChangedCallback,
    this.enableRotation = false,
    this.scrollPhysics,
    this.scrollDirection = Axis.horizontal,
    this.customSize,
    this.allowImplicitScrolling = false,
  })  : itemCount = null,
        builder = null,
        super(key: key);

  const EHPhotoViewGallery.builder({
    Key? key,
    required this.cacheExtent,
    required this.itemCount,
    required this.builder,
    this.loadingBuilder,
    this.backgroundDecoration,
    this.wantKeepAlive = false,
    this.gaplessPlayback = false,
    this.reverse = false,
    this.pageController,
    this.onPageChanged,
    this.scaleStateChangedCallback,
    this.enableRotation = false,
    this.scrollPhysics,
    this.scrollDirection = Axis.horizontal,
    this.customSize,
    this.allowImplicitScrolling = false,
  })  : pageOptions = null,
        assert(itemCount != null),
        assert(builder != null),
        super(key: key);

  /// A list of options to describe the items in the gallery
  final List<PhotoViewGalleryPageOptions>? pageOptions;

  /// The count of items in the gallery, only used when constructed via [EHPhotoViewGallery.builder]
  final int? itemCount;

  /// Called to build items for the gallery when using [EHPhotoViewGallery.builder]
  final PhotoViewGalleryBuilder? builder;

  /// [ScrollPhysics] for the internal [PageView]
  final ScrollPhysics? scrollPhysics;

  /// Mirror to [PhotoView.loadingBuilder]
  final LoadingBuilder? loadingBuilder;

  /// Mirror to [PhotoView.backgroundDecoration]
  final BoxDecoration? backgroundDecoration;

  /// Mirror to [PhotoView.wantKeepAlive]
  final bool wantKeepAlive;

  /// Mirror to [PhotoView.gaplessPlayback]
  final bool gaplessPlayback;

  /// Mirror to [PageView.reverse]
  final bool reverse;

  /// An object that controls the [PageView] inside [EHPhotoViewGallery]
  final PageController? pageController;

  /// An callback to be called on a page change
  final PhotoViewGalleryPageChangedCallback? onPageChanged;

  /// Mirror to [PhotoView.scaleStateChangedCallback]
  final ValueChanged<PhotoViewScaleState>? scaleStateChangedCallback;

  /// Mirror to [PhotoView.enableRotation]
  final bool enableRotation;

  /// Mirror to [PhotoView.customSize]
  final Size? customSize;

  /// The axis along which the [PageView] scrolls. Mirror to [PageView.scrollDirection]
  final Axis scrollDirection;

  /// When user attempts to move it to the next element, focus will traverse to the next page in the page view.
  final bool allowImplicitScrolling;

  bool get _isBuilder => builder != null;

  @override
  State<StatefulWidget> createState() {
    return _EHPhotoViewGalleryState();
  }
}

class _EHPhotoViewGalleryState extends State<EHPhotoViewGallery> {
  late final PageController _controller = widget.pageController ?? PageController();

  void scaleStateChangedCallback(PhotoViewScaleState scaleState) {
    if (widget.scaleStateChangedCallback != null) {
      widget.scaleStateChangedCallback!(scaleState);
    }
  }

  int get actualPage {
    return _controller.hasClients ? _controller.page!.floor() : 0;
  }

  int get itemCount {
    if (widget._isBuilder) {
      return widget.itemCount!;
    }
    return widget.pageOptions!.length;
  }

  @override
  Widget build(BuildContext context) {
    // Enable corner hit test
    return PhotoViewGestureDetectorScope(
      axis: widget.scrollDirection,
      child: EhPageView.builder(
        cacheExtent: widget.cacheExtent,
        reverse: widget.reverse,
        controller: _controller,
        onPageChanged: widget.onPageChanged,
        itemCount: itemCount,
        itemBuilder: _buildItem,
        scrollDirection: widget.scrollDirection,
        physics: widget.scrollPhysics,
        allowImplicitScrolling: widget.allowImplicitScrolling,
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final pageOption = _buildPageOption(context, index);
    final isCustomChild = pageOption.child != null;

    final PhotoView photoView = isCustomChild
        ? PhotoView.customChild(
            key: ObjectKey(index),
            child: pageOption.child,
            childSize: pageOption.childSize,
            backgroundDecoration: widget.backgroundDecoration,
            wantKeepAlive: widget.wantKeepAlive,
            controller: pageOption.controller,
            scaleStateController: pageOption.scaleStateController,
            customSize: widget.customSize,
            heroAttributes: pageOption.heroAttributes,
            scaleStateChangedCallback: scaleStateChangedCallback,
            enableRotation: widget.enableRotation,
            initialScale: pageOption.initialScale,
            minScale: pageOption.minScale,
            maxScale: pageOption.maxScale,
            scaleStateCycle: pageOption.scaleStateCycle,
            onTapUp: pageOption.onTapUp,
            onTapDown: pageOption.onTapDown,
            onScaleEnd: pageOption.onScaleEnd,
            gestureDetectorBehavior: pageOption.gestureDetectorBehavior,
            tightMode: pageOption.tightMode,
            filterQuality: pageOption.filterQuality,
            basePosition: pageOption.basePosition,
            disableGestures: pageOption.disableGestures,
          )
        : PhotoView(
            key: ObjectKey(index),
            imageProvider: pageOption.imageProvider,
            loadingBuilder: widget.loadingBuilder,
            backgroundDecoration: widget.backgroundDecoration,
            wantKeepAlive: widget.wantKeepAlive,
            controller: pageOption.controller,
            scaleStateController: pageOption.scaleStateController,
            customSize: widget.customSize,
            gaplessPlayback: widget.gaplessPlayback,
            heroAttributes: pageOption.heroAttributes,
            scaleStateChangedCallback: scaleStateChangedCallback,
            enableRotation: widget.enableRotation,
            initialScale: pageOption.initialScale,
            minScale: pageOption.minScale,
            maxScale: pageOption.maxScale,
            scaleStateCycle: pageOption.scaleStateCycle,
            onTapUp: pageOption.onTapUp,
            onTapDown: pageOption.onTapDown,
            onScaleEnd: pageOption.onScaleEnd,
            gestureDetectorBehavior: pageOption.gestureDetectorBehavior,
            tightMode: pageOption.tightMode,
            filterQuality: pageOption.filterQuality,
            basePosition: pageOption.basePosition,
            disableGestures: pageOption.disableGestures,
            errorBuilder: pageOption.errorBuilder,
          );

    return ClipRect(
      child: photoView,
    );
  }

  PhotoViewGalleryPageOptions _buildPageOption(BuildContext context, int index) {
    if (widget._isBuilder) {
      return widget.builder!(context, index);
    }
    return widget.pageOptions![index];
  }
}
