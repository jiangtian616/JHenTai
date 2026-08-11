import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';

import '../model/gallery_image.dart';
import '../service/reader_thumbnail_request_controller.dart';
import 'eh_image.dart';

class EHThumbnail extends StatefulWidget {
  final GalleryThumbnail thumbnail;
  final double? containerHeight;
  final double? containerWidth;
  final BorderRadius borderRadius;

  const EHThumbnail({
    Key? key,
    required this.thumbnail,
    this.containerHeight,
    this.containerWidth,
    this.borderRadius = BorderRadius.zero,
  }) : super(key: key);

  @override
  State<EHThumbnail> createState() => _EHThumbnailState();
}

class _EHThumbnailState extends State<EHThumbnail> {
  late ReaderThumbnailRequestController _requestController;
  late String _requestIdentity;
  late CancellationToken _cancelToken;
  late ReaderThumbnailRequestToken _requestToken;
  int _attempt = 0;

  String get _identity => _thumbnailIdentity(widget.thumbnail);

  @override
  void initState() {
    super.initState();
    _requestIdentity = _identity;
    _cancelToken = CancellationToken();
    _requestController = ReaderThumbnailRequestController(
      onRetryRequested: _restartProviderAttempt,
      onAttemptTimedOut:
          (_) => _cancelToken.cancel('thumbnail watchdog timeout'),
      onStatusChanged: (_) => _scheduleRebuild(),
    );
    _requestToken = _requestController.start(_requestIdentity);
  }

  @override
  void didUpdateWidget(covariant EHThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextIdentity = _identity;
    if (_requestIdentity == nextIdentity) {
      return;
    }

    _cancelToken.cancel('thumbnail request replaced');
    _requestController.cancel();
    _requestIdentity = nextIdentity;
    _attempt = 0;
    _cancelToken = CancellationToken();
    _requestToken = _requestController.start(_requestIdentity);
  }

  @override
  void dispose() {
    _cancelToken.cancel('thumbnail disposed');
    _requestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_requestController.status == ReaderThumbnailLoadStatus.failed) {
      return _buildFailurePlaceholder();
    }

    final GalleryThumbnail thumbnail = widget.thumbnail;
    final ReaderThumbnailRequestToken token = _requestToken;
    return EHImage(
      key: ValueKey<String>('$_requestIdentity::$_attempt'),
      galleryImage: GalleryImage(url: thumbnail.thumbUrl),
      containerHeight: widget.containerHeight,
      containerWidth: widget.containerWidth,
      borderRadius: widget.borderRadius,
      // The controller is the hard watchdog. This option is also passed to
      // the provider for platforms/dependency versions that honor it.
      timeLimit: ReaderThumbnailRequestController.defaultWatchdogMilliseconds,
      cancelToken: _cancelToken,
      maxBytes: thumbnail.isLarge ? 512 * 1024 : 256 * 1024,
      onLoading: (state) => _requestController.progress(token),
      loadingProgressWidgetBuilder: (_) {
        _requestController.progress(token);
        return Center(child: _loadingWidget(context));
      },
      failedWidgetBuilder: (state) {
        _requestController.failed(token);
        return _buildFailurePlaceholder(onRetry: _retry);
      },
      completedWidgetBuilder: (state) {
        _requestController.completed(token);
        return thumbnail.isLarge
            ? null
            : _buildSmallThumbnailCrop(thumbnail, state);
      },
    );
  }

  Widget _buildSmallThumbnailCrop(
    GalleryThumbnail thumbnail,
    ExtendedImageState state,
  ) {
    final ui.Image? image = state.extendedImageInfo?.image;
    if (image == null ||
        thumbnail.thumbWidth == null ||
        thumbnail.thumbHeight == null ||
        thumbnail.offSet == null ||
        thumbnail.thumbHeight! <= 0) {
      return const SizedBox.shrink();
    }

    final FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      Size(thumbnail.thumbWidth!, thumbnail.thumbHeight!),
      Size(
        widget.containerWidth ?? double.infinity,
        widget.containerHeight ?? double.infinity,
      ),
    );
    final double scale = image.height / thumbnail.thumbHeight!;
    return ExtendedRawImage(
      image: image,
      fit: BoxFit.fill,
      height: fittedSizes.destination.height,
      width: fittedSizes.destination.width,
      sourceRect: Rect.fromLTRB(
        thumbnail.offSet! * scale,
        0,
        (thumbnail.offSet! + thumbnail.thumbWidth!) * scale,
        thumbnail.thumbHeight! * scale,
      ),
    );
  }

  Widget _buildFailurePlaceholder({VoidCallback? onRetry}) {
    return GestureDetector(
      key: const Key('reader-thumbnail-retry'),
      behavior: HitTestBehavior.opaque,
      onTap: onRetry ?? _retry,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const Icon(Icons.refresh), Text('retry'.tr)],
        ),
      ),
    );
  }

  Widget _loadingWidget(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  void _retry() {
    if (!mounted) {
      return;
    }
    _cancelToken.cancel('thumbnail manual retry');
    _requestController.retry();
  }

  void _restartProviderAttempt(ReaderThumbnailRequestToken token) {
    if (!mounted || token.identity != _requestIdentity) {
      return;
    }
    _cancelToken.cancel('thumbnail attempt replaced');
    _cancelToken = CancellationToken();
    _requestToken = token;
    _attempt++;
    setState(() {});
  }

  void _scheduleRebuild() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  static String _thumbnailIdentity(GalleryThumbnail thumbnail) {
    return <Object?>[
      thumbnail.thumbUrl,
      thumbnail.isLarge,
      thumbnail.thumbWidth,
      thumbnail.thumbHeight,
      thumbnail.offSet,
    ].join('|');
  }
}
