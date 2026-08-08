import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

export '_extended_network_image_utils_io.dart'
    if (dart.library.html) '_extended_network_image_utils_web.dart';
export '_platform_io.dart' if (dart.library.html) '_platform_web.dart';

const String cacheImageFolderName = 'cacheimage';

/// Events reported by the disk image cache so the host app can keep usage
/// statistics for space-limit eviction.
enum ExtendedImageCacheEventType { hit, written, deleted, cleared }

typedef ExtendedImageCacheObserver =
    void Function(String key, ExtendedImageCacheEventType event);

String? _diskCacheDirectory;
ExtendedImageCacheObserver? _cacheObserver;

/// Overrides the directory used for the disk image cache.
/// When unset, the default `<system temp>/cacheimage` is used.
String? get extendedImageDiskCacheDirectory => _diskCacheDirectory;
set extendedImageDiskCacheDirectory(String? value) =>
    _diskCacheDirectory = value;

/// Observer notified on disk cache hits/writes/deletes. Set by the host app.
ExtendedImageCacheObserver? get extendedImageCacheObserver => _cacheObserver;
set extendedImageCacheObserver(ExtendedImageCacheObserver? value) =>
    _cacheObserver = value;

void notifyExtendedImageCacheEvent(
    String key, ExtendedImageCacheEventType event) {
  _cacheObserver?.call(key, event);
}

/// Resolves the disk cache directory, honoring
/// [extendedImageDiskCacheDirectory] when it is set.
Future<String> getExtendedImageDiskCacheDirectory() async {
  final String? override = _diskCacheDirectory;
  if (override != null && override.isNotEmpty) {
    return override;
  }
  return join((await getTemporaryDirectory()).path, cacheImageFolderName);
}

///clear all of image in memory
void clearMemoryImageCache([String? name]) {
  if (name != null) {
    if (imageCaches.containsKey(name)) {
      imageCaches[name]!.clear();
      imageCaches[name]!.clearLiveImages();
      imageCaches.remove(name);
    }
  } else {
    PaintingBinding.instance.imageCache.clear();

    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

/// get ImageCache
ImageCache? getMemoryImageCache([String? name]) {
  if (name != null) {
    if (imageCaches.containsKey(name)) {
      return imageCaches[name];
    } else {
      return null;
    }
  } else {
    return PaintingBinding.instance.imageCache;
  }
}

/// get network image data from cached
Future<Uint8List?> getNetworkImageData(
  String url, {
  bool useCache = true,
  StreamController<ImageChunkEvent>? chunkEvents,
}) async {
  return ExtendedNetworkImageProvider(url, cache: useCache).getNetworkImageData(
    chunkEvents: chunkEvents,
  );
}

/// get md5 from key
String keyToMd5(String key) => md5.convert(utf8.encode(key)).toString();
