import 'dart:typed_data';
import 'dart:ui' as ui show Codec;
import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:flutter/widgets.dart';

class ExtendedMemoryImageProvider extends MemoryImage
    with ExtendedImageProvider<MemoryImage> {
  const ExtendedMemoryImageProvider(
    Uint8List bytes, {
    double scale = 1.0,
    this.cacheRawData = false,
    this.imageCacheName,
  }) : super(bytes, scale: scale);

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  @override
  Uint8List get rawImageData => bytes;

  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<ui.Codec> _loadAsync(MemoryImage key, ImageDecoderCallback decode) {
    assert(key == this);
    return instantiateImageCodec(bytes, decode);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedMemoryImageProvider &&
        other.bytes == bytes &&
        other.scale == scale &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        bytes.hashCode,
        scale,
        cacheRawData,
        imageCacheName,
      );
}
