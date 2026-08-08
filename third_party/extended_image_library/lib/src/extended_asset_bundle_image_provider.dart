import 'dart:async';
import 'dart:ui' as ui show Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'extended_image_provider.dart';

class ExtendedExactAssetImageProvider extends ExactAssetImage
    with ExtendedImageProvider<AssetBundleImageKey> {
  const ExtendedExactAssetImageProvider(
    String assetName, {
    AssetBundle? bundle,
    String? package,
    double scale = 1.0,
    this.cacheRawData = false,
    this.imageCacheName,
  }) : super(assetName, bundle: bundle, package: package, scale: scale);

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
  Future<ExtendedAssetBundleImageKey> obtainKey(
      ImageConfiguration configuration) {
    final Completer<ExtendedAssetBundleImageKey> completer =
        Completer<ExtendedAssetBundleImageKey>();
    super.obtainKey(configuration).then((AssetBundleImageKey value) {
      completer.complete(ExtendedAssetBundleImageKey(
        bundle: value.bundle,
        scale: value.scale,
        name: value.name,
        cacheRawData: cacheRawData,
        imageCacheName: imageCacheName,
      ));
    });
    return completer.future;
  }

  @override
  ImageStreamCompleter loadImage(
      AssetBundleImageKey key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AssetBundleImageKey>('Image key', key);
      },
    );
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ui.Codec> _loadAsync(
      AssetBundleImageKey key, ImageDecoderCallback decode) async {
    ByteData data;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      data = await key.bundle.load(key.name);
    } on FlutterError {
      this.imageCache.evict(key);
      rethrow;
    }
    final Uint8List result = data.buffer.asUint8List();
    return await instantiateImageCodec(result, decode);
  }
}

class ExtendedAssetImageProvider extends AssetImage
    with ExtendedImageProvider<AssetBundleImageKey> {
  const ExtendedAssetImageProvider(
    String assetName, {
    AssetBundle? bundle,
    String? package,
    this.cacheRawData = false,
    this.imageCacheName,
  }) : super(assetName, bundle: bundle, package: package);

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
  Future<ExtendedAssetBundleImageKey> obtainKey(
      ImageConfiguration configuration) {
    final Completer<ExtendedAssetBundleImageKey> completer =
        Completer<ExtendedAssetBundleImageKey>();
    super.obtainKey(configuration).then((AssetBundleImageKey value) {
      completer.complete(ExtendedAssetBundleImageKey(
        bundle: value.bundle,
        scale: value.scale,
        name: value.name,
        cacheRawData: cacheRawData,
        imageCacheName: imageCacheName,
      ));
    });
    return completer.future;
  }

  @override
  ImageStreamCompleter loadImage(
      AssetBundleImageKey key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AssetBundleImageKey>('Image key', key);
      },
    );
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ui.Codec> _loadAsync(
      AssetBundleImageKey key, ImageDecoderCallback decode) async {
    ByteData data;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      data = await key.bundle.load(key.name);
    } on FlutterError {
      this.imageCache.evict(key);
      rethrow;
    }

    final Uint8List result = data.buffer.asUint8List();
    return await instantiateImageCodec(result, decode);
  }
}

class ExtendedAssetBundleImageKey extends AssetBundleImageKey {
  const ExtendedAssetBundleImageKey({
    required AssetBundle bundle,
    required String name,
    required double scale,
    required this.cacheRawData,
    required this.imageCacheName,
  }) : super(bundle: bundle, name: name, scale: scale);

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.

  final String? imageCacheName;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedAssetBundleImageKey &&
        bundle == other.bundle &&
        name == other.name &&
        scale == other.scale &&
        cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        bundle,
        name,
        scale,
        cacheRawData,
        imageCacheName,
      );
}
