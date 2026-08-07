import 'dart:async';
import '_platform_web.dart';

/// clear the disk cache directory then return if it succeed.
///  <param name="duration">timespan to compute whether file has expired or not</param>
Future<bool> clearDiskCachedImages({Duration? duration}) async {
  assert(false, 'not support on web');
  return false;
}

/// clear the disk cache image then return if it succeed.
///  <param name="url">clear specific one</param>
Future<bool> clearDiskCachedImage(String url, {String? cacheKey}) async {
  assert(false, 'not support on web');
  return false;
}

/// Get the local file of the cached image

Future<File?> getCachedImageFile(String url, {String? cacheKey}) async {
  assert(false, 'not support on web');
  return null;
}

/// Check if the image exists in cache
Future<bool> cachedImageExists(String url, {String? cacheKey}) async {
  assert(false, 'not support on web');
  return false;
}

/// Get total size of cached image
Future<int> getCachedSizeBytes() async {
  assert(false, 'not support on web');
  return 0;
}

/// Get the local file path of the cached image
Future<String?> getCachedImageFilePath(String url, {String? cacheKey}) async {
  assert(false, 'not support on web');
  return null;
}
