import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'platform.dart';

/// Clear the disk cache directory then return if it succeed.
Future<bool> clearDiskCachedImages({Duration? duration}) async {
  try {
    final Directory cacheImagesDirectory =
        Directory(await getExtendedImageDiskCacheDirectory());
    if (cacheImagesDirectory.existsSync()) {
      if (duration == null) {
        cacheImagesDirectory.deleteSync(recursive: true);
        await cacheImagesDirectory.create(recursive: true);
        notifyExtendedImageCacheEvent(
            '', ExtendedImageCacheEventType.cleared);
      } else {
        final DateTime now = DateTime.now();
        await for (final FileSystemEntity file in cacheImagesDirectory.list()) {
          final FileStat fs = file.statSync();
          if (now.subtract(duration).isAfter(fs.changed)) {
            file.deleteSync(recursive: true);
            notifyExtendedImageCacheEvent(
                basename(file.path), ExtendedImageCacheEventType.deleted);
          }
        }
      }
    }
  } catch (_) {
    return false;
  }
  return true;
}

/// Clear the disk cache image then return if it succeed.
Future<bool> clearDiskCachedImage(String url, {String? cacheKey}) async {
  try {
    final String key = cacheKey ?? keyToMd5(url);
    final File? file = await getCachedImageFile(url, cacheKey: cacheKey);
    if (file != null) {
      await file.delete(recursive: true);
      notifyExtendedImageCacheEvent(
          key, ExtendedImageCacheEventType.deleted);
    }
  } catch (_) {
    return false;
  }
  return true;
}

/// Get the local file of the cached image

Future<File?> getCachedImageFile(String url, {String? cacheKey}) async {
  try {
    final String key = cacheKey ?? keyToMd5(url);
    final Directory cacheImagesDirectory =
        Directory(await getExtendedImageDiskCacheDirectory());
    if (cacheImagesDirectory.existsSync()) {
      final File file = File(join(cacheImagesDirectory.path, key));
      if (file.existsSync()) {
        notifyExtendedImageCacheEvent(key, ExtendedImageCacheEventType.hit);
        return file;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Check if the image exists in cache
Future<bool> cachedImageExists(String url, {String? cacheKey}) async {
  try {
    final String key = cacheKey ?? keyToMd5(url);
    final Directory cacheImagesDirectory =
        Directory(await getExtendedImageDiskCacheDirectory());
    if (cacheImagesDirectory.existsSync()) {
      final File file = File(join(cacheImagesDirectory.path, key));
      if (file.existsSync()) {
        notifyExtendedImageCacheEvent(key, ExtendedImageCacheEventType.hit);
        return true;
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

/// Get total size of cached image
Future<int> getCachedSizeBytes() async {
  int size = 0;
  final Directory cacheImagesDirectory =
      Directory(await getExtendedImageDiskCacheDirectory());
  if (cacheImagesDirectory.existsSync()) {
    await for (final FileSystemEntity file in cacheImagesDirectory.list()) {
      size += file.statSync().size;
    }
  }
  return size;
}

/// Get the local file path of the cached image
Future<String?> getCachedImageFilePath(String url, {String? cacheKey}) async {
  final File? file = await getCachedImageFile(url, cacheKey: cacheKey);
  return file?.path;
}
