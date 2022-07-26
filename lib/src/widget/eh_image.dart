import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'dart:io' as io;

import 'package:path/path.dart' as path;

import '../setting/network_setting.dart';
import '../setting/path_setting.dart';
import '../utils/route_util.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef CompletedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();

class EHImage extends StatefulWidget {
  final GalleryImage galleryImage;
  final double? containerHeight;
  final double? containerWidth;
  final Color? containerColor;
  final bool adaptive;
  final BoxFit? fit;
  final ExtendedImageMode mode;
  final InitGestureConfigHandler? initGestureConfigHandler;
  LoadingProgressWidgetBuilder? loadingWidgetBuilder;
  FailedWidgetBuilder? failedWidgetBuilder;
  DownloadingWidgetBuilder? downloadingWidgetBuilder;
  PausedWidgetBuilder? pausedWidgetBuilder;
  CompletedWidgetBuilder? completedWidgetBuilder;

  EHImage.file({
    Key? key,
    required this.galleryImage,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.adaptive = false,
    this.fit,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.completedWidgetBuilder,
  }) : super(key: key);

  EHImage.network({
    Key? key,
    required this.galleryImage,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.adaptive = false,
    this.fit,
    this.mode = ExtendedImageMode.none,
    this.initGestureConfigHandler,
    this.loadingWidgetBuilder,
    this.failedWidgetBuilder,
    this.completedWidgetBuilder,
  }) : super(key: key);

  @override
  _EHImageState createState() => _EHImageState();
}

class _EHImageState extends State<EHImage> {
  Key? key;
  CancellationToken? cancelToken;

  @override
  void initState() {
    /// online mode
    if (widget.galleryImage.path == null) {
      key = UniqueKey();
      cancelToken = CancellationToken();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.containerHeight,
      width: widget.containerWidth,
      color: widget.containerColor,
      child: widget.galleryImage.path == null ? buildNetworkImage(context) : buildFileImage(context),
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _showReloadBottomSheet,
      child: ExtendedImage.network(
        _replaceEXUrl(widget.galleryImage.url),
        key: key,
        height: widget.adaptive ? null : widget.galleryImage.height,
        width: widget.adaptive ? null : widget.galleryImage.width,
        fit: widget.fit,
        mode: widget.mode,
        initGestureConfigHandler: widget.initGestureConfigHandler,
        cancelToken: cancelToken,
        clearMemoryCacheWhenDispose: true,
        handleLoadingProgress: widget.loadingWidgetBuilder != null,
        printError: false,
        // headers: _cookieHeaders(widget.galleryImage.url),
        loadStateChanged: (ExtendedImageState state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return widget.loadingWidgetBuilder?.call(
                _computeLoadingProgress(state.loadingProgress, state.extendedImageInfo),
              );
            case LoadState.failed:
              return widget.failedWidgetBuilder?.call(state);
            case LoadState.completed:
              return FadeIn(
                child: widget.completedWidgetBuilder?.call(state) ?? _getCompletedWidget(state),
              );
          }
        },
      ),
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (widget.galleryImage.downloadStatus == DownloadStatus.paused) {
      return widget.pausedWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    if (widget.galleryImage.downloadStatus == DownloadStatus.downloading) {
      return widget.downloadingWidgetBuilder?.call() ?? const Center(child: CircularProgressIndicator());
    }

    return ExtendedImage.file(
      io.File(path.join(PathSetting.getVisibleDir().path, widget.galleryImage.path!)),
      key: key,
      height: widget.adaptive ? null : widget.galleryImage.height,
      width: widget.adaptive ? null : widget.galleryImage.width,
      fit: widget.fit,
      mode: widget.mode,
      enableLoadState: true,
      clearMemoryCacheWhenDispose: true,
      loadStateChanged: (ExtendedImageState state) {
        if (state.extendedImageLoadState == LoadState.completed) {
          return FadeIn(
            child: widget.completedWidgetBuilder?.call(state) ?? _getCompletedWidget(state),
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

  void _showReloadBottomSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('reloadImage'.tr),
            onPressed: () async {
              cancelToken?.cancel();
              await clearDiskCachedImage(widget.galleryImage.url);
              clearMemoryImageCache(widget.galleryImage.url);
              setState(() {
                /// lead to rebuilding
                key = UniqueKey();
                cancelToken = CancellationToken();
              });
              back();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => back(),
        ),
      ),
    );
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
    if (widget.mode == ExtendedImageMode.gesture) {
      return ExtendedImageGesture(state);
    }
    if (widget.mode == ExtendedImageMode.editor) {
      return ExtendedImageEditor(extendedImageState: state);
    }
    return _buildExtendedRawImage(state);
  }

  /// copied from ExtendedImage
  Widget _buildExtendedRawImage(ExtendedImageState state) {
    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      width: widget.adaptive ? null : widget.galleryImage.width,
      height: widget.adaptive ? null : widget.galleryImage.height,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: widget.fit,
      alignment: Alignment.center,
      repeat: ImageRepeat.noRepeat,
      matchTextDirection: false,
      isAntiAlias: false,
      filterQuality: FilterQuality.low,
    );
  }
}
