import 'dart:ui' as ui show Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide FileImage;
import 'extended_image_provider.dart';
import 'platform.dart';

class ExtendedFileImageProvider extends FileImage
    with ExtendedImageProvider<FileImage> {
  const ExtendedFileImageProvider(
    File file, {
    double scale = 1.0,
    this.cacheRawData = false,
    this.imageCacheName,
  })  : assert(!kIsWeb, 'not support on web'),
        super(file, scale: scale);

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
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
      FileImage key, ImageDecoderCallback decode) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      this.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }

    return await instantiateImageCodec(bytes, decode);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedFileImageProvider &&
        file.path == other.file.path &&
        scale == other.scale &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        file.path,
        scale,
        cacheRawData,
        imageCacheName,
      );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'FileImage')}("${file.path}", scale: $scale)';
}
