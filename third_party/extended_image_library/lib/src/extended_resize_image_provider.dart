import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'extended_image_provider.dart';

/// Instructs Flutter to decode the image at the specified dimensions
/// instead of at its native size.
///
/// This allows finer control of the size of the image in [ImageCache] and is
/// generally used to reduce the memory footprint of [ImageCache].
///
/// The decoded image may still be displayed at sizes other than the
/// cached size provided here.
class ExtendedResizeImage extends ImageProvider<_SizeAwareCacheKey>
    with ExtendedImageProvider<_SizeAwareCacheKey> {
  const ExtendedResizeImage(
    this.imageProvider, {
    this.compressionRatio,
    this.maxBytes = 50 << 10,
    this.width,
    this.height,
    this.allowUpscaling = false,
    this.cacheRawData = false,
    this.imageCacheName,
    this.policy = ResizeImagePolicy.exact,
  }) : assert((compressionRatio != null &&
                compressionRatio > 0 &&
                compressionRatio < 1 &&
                !kIsWeb) ||
            (maxBytes != null && maxBytes > 0 && !kIsWeb) ||
            width != null ||
            height != null);

  /// The [ImageProvider] that this class wraps.
  final ImageProvider imageProvider;

  /// [ExtendedResizeImage] will compress the image to a size
  /// that is smaller than [maxBytes]. The default size is 50KB.
  /// It's actual bytes of Image, not decode bytes
  /// it's not supported on web
  final int? maxBytes;

  /// The image`s size will resize to original * [compressionRatio].
  /// It's ExtendedResizeImage`s first pick.
  /// The compressionRatio`s range is from 0.0 (exclusive), to
  /// 1.0 (exclusive).
  /// it's not supported on web
  final double? compressionRatio;

  /// The width the image should decode to and cache.
  final int? width;

  /// The height the image should decode to and cache.
  final int? height;

  /// The policy that determines how [width] and [height] are interpreted.
  ///
  /// Defaults to [ResizeImagePolicy.exact].
  final ResizeImagePolicy policy;

  /// Whether the [width] and [height] parameters should be clamped to the
  /// intrinsic width and height of the image.
  ///
  /// In general, it is better for memory usage to avoid scaling the image
  /// beyond its intrinsic dimensions when decoding it. If there is a need to
  /// scale an image larger, it is better to apply a scale to the canvas, or
  /// to use an appropriate [Image.fit].
  final bool allowUpscaling;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// Composes the `provider` in a [ResizeImage] only when `cacheWidth` and
  /// `cacheHeight` are not both null.
  ///
  /// When `cacheWidth` and `cacheHeight` are both null, this will return the
  /// `provider` directly.
  ///
  /// Extended with `scaling` and `maxBytes`.
  static ImageProvider<Object> resizeIfNeeded({
    required ImageProvider<Object> provider,
    int? cacheWidth,
    int? cacheHeight,
    double? compressionRatio,
    int? maxBytes,
    bool cacheRawData = false,
    String? imageCacheName,
  }) {
    if ((compressionRatio != null &&
            compressionRatio > 0 &&
            compressionRatio < 1) ||
        (maxBytes != null && maxBytes > 0) ||
        cacheWidth != null ||
        cacheHeight != null) {
      return ExtendedResizeImage(
        provider,
        width: cacheWidth,
        height: cacheHeight,
        maxBytes: maxBytes,
        compressionRatio: compressionRatio,
        cacheRawData: cacheRawData,
        imageCacheName: imageCacheName,
      );
    }
    return provider;
  }

  @override
  ImageStreamCompleter loadImage(
      _SizeAwareCacheKey key, ImageDecoderCallback decode) {
    Future<Codec> decodeResize(
      ImmutableBuffer buffer, {
      TargetImageSizeCallback? getTargetSize,
    }) {
      assert(
        getTargetSize == null,
        'ResizeImage cannot be composed with another ImageProvider that applies '
        'cacheWidth, cacheHeight, or allowUpscaling.',
      );

      return _instantiateImageCodec(
        buffer,
        decode,
        compressionRatio: compressionRatio,
        maxBytes: maxBytes,
        targetWidth: width,
        targetHeight: height,
      );
    }

    final ImageStreamCompleter completer =
        imageProvider.loadImage(key._providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - Resized(${key._width}×${key._height})';
    }

    return completer;
  }

  @override
  Future<_SizeAwareCacheKey> obtainKey(ImageConfiguration configuration) {
    Completer<_SizeAwareCacheKey>? completer;
    // If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
    // a value before completer is initialized below.
    SynchronousFuture<_SizeAwareCacheKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      if (completer == null) {
        // This future has completed synchronously (completer was never assigned),
        // so we can directly create the synchronous result to return.
        result = SynchronousFuture<_SizeAwareCacheKey>(_SizeAwareCacheKey(
          key,
          compressionRatio,
          maxBytes,
          width,
          height,
          cacheRawData,
          imageCacheName,
        ));
      } else {
        // This future did not synchronously complete.
        completer.complete(_SizeAwareCacheKey(
          key,
          compressionRatio,
          maxBytes,
          width,
          height,
          cacheRawData,
          imageCacheName,
        ));
      }
    });
    if (result != null) {
      return result!;
    }
    // If the code reaches here, it means the imageProvider.obtainKey was not
    // completed sync, so we initialize the completer for completion later.
    completer = Completer<_SizeAwareCacheKey>();
    return completer.future;
  }

  Future<Codec> _instantiateImageCodec(
    ImmutableBuffer buffer,
    ImageDecoderCallback decode, {
    double? compressionRatio,
    int? maxBytes,
    int? targetWidth,
    int? targetHeight,
  }) async {
    if (!kIsWeb &&
        (compressionRatio != null ||
            (maxBytes != null && maxBytes < buffer.length))) {
      final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
      final int totalBytes =
          descriptor.width * descriptor.height * descriptor.bytesPerPixel;
      if (compressionRatio != null) {
        final _IntSize size = _resize(
          descriptor.width,
          descriptor.height,
          (totalBytes * compressionRatio).toInt(),
          descriptor.bytesPerPixel,
        );
        targetWidth = size.width;
        targetHeight = size.height;
      } else if (maxBytes != null && maxBytes < buffer.length) {
        final _IntSize size = _resize(
          descriptor.width,
          descriptor.height,
          totalBytes * maxBytes ~/ buffer.length,
          descriptor.bytesPerPixel,
        );
        targetWidth = size.width;
        targetHeight = size.height;
      }

      return descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    } else {
      return decode(buffer,
          getTargetSize: (int intrinsicWidth, int intrinsicHeight) {
        switch (policy) {
          case ResizeImagePolicy.exact:
            int? targetWidth = width;
            int? targetHeight = height;

            if (!allowUpscaling) {
              if (targetWidth != null && targetWidth > intrinsicWidth) {
                targetWidth = intrinsicWidth;
              }
              if (targetHeight != null && targetHeight > intrinsicHeight) {
                targetHeight = intrinsicHeight;
              }
            }

            return TargetImageSize(width: targetWidth, height: targetHeight);
          case ResizeImagePolicy.fit:
            final double aspectRatio = intrinsicWidth / intrinsicHeight;
            final int maxWidth = width ?? intrinsicWidth;
            final int maxHeight = height ?? intrinsicHeight;
            int targetWidth = intrinsicWidth;
            int targetHeight = intrinsicHeight;

            if (targetWidth > maxWidth) {
              targetWidth = maxWidth;
              targetHeight = targetWidth ~/ aspectRatio;
            }

            if (targetHeight > maxHeight) {
              targetHeight = maxHeight;
              targetWidth = (targetHeight * aspectRatio).floor();
            }

            if (allowUpscaling) {
              if (width == null) {
                assert(height != null);
                targetHeight = height!;
                targetWidth = (targetHeight * aspectRatio).floor();
              } else if (height == null) {
                targetWidth = width!;
                targetHeight = targetWidth ~/ aspectRatio;
              } else {
                final int derivedMaxWidth = (maxHeight * aspectRatio).floor();
                final int derivedMaxHeight = maxWidth ~/ aspectRatio;
                targetWidth = min(maxWidth, derivedMaxWidth);
                targetHeight = min(maxHeight, derivedMaxHeight);
              }
            }

            return TargetImageSize(width: targetWidth, height: targetHeight);
        }
      });
    }
  }

  /// Calculate fittest size.
  /// [width] The image's original width.
  /// [height] The image's original height.
  /// [maxBytes] The size that image will resize to.
  ///
  _IntSize _resize(int width, int height, int maxBytes, int bytesPerPixel) {
    final double ratio = width / height;
    final int maxSize_1_4 = maxBytes ~/ bytesPerPixel;
    final int targetHeight = sqrt(maxSize_1_4 / ratio).floor();
    final int targetWidth = (ratio * targetHeight).floor();
    return _IntSize(targetWidth, targetHeight);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedResizeImage &&
        imageProvider == other.imageProvider &&
        compressionRatio == other.compressionRatio &&
        maxBytes == other.maxBytes &&
        width == other.width &&
        height == other.height &&
        allowUpscaling == other.allowUpscaling &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        imageProvider,
        compressionRatio,
        maxBytes,
        width,
        height,
        allowUpscaling,
        cacheRawData,
        imageCacheName,
      );
}

@immutable
class _IntSize {
  const _IntSize(this.width, this.height);

  final int width;
  final int height;
}

@immutable
class _SizeAwareCacheKey {
  const _SizeAwareCacheKey(
    this._providerCacheKey,
    this.compressionRatio,
    this.maxBytes,
    this._width,
    this._height,
    this.cacheRawData,
    this.imageCacheName,
  );

  final Object _providerCacheKey;

  final int? maxBytes;

  final double? compressionRatio;

  final int? _width;

  final int? _height;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.

  final String? imageCacheName;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _SizeAwareCacheKey &&
        other._providerCacheKey == _providerCacheKey &&
        other.maxBytes == maxBytes &&
        other.compressionRatio == compressionRatio &&
        other._width == _width &&
        other._height == _height &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        _providerCacheKey,
        maxBytes,
        compressionRatio,
        _width,
        _height,
        cacheRawData,
        imageCacheName,
      );
}
