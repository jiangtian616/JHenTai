import 'dart:io';

import 'package:extended_image_library/extended_image_library.dart';
import 'package:path/path.dart' as path;

/// Applies the same host rewrite used by EHImage before network and cache work.
String effectiveEHImageUrl(String url) {
  final Uri? rawUri = Uri.tryParse(url);
  if (rawUri == null || rawUri.host != 's.exhentai.org') {
    return url;
  }
  return rawUri.replace(host: 'ehgt.org').toString();
}

/// Returns a stable disk-cache key for an E-Hentai image URL.
///
/// EH image URLs carry a time-limited `keystamp=<ts>-<key>` token, can switch
/// H@H subdomain/port, and can alternate between the `/h/<sha>-.../` and the
/// `/om/<fileindex>/...` formats between fetches. Keying the disk cache by the
/// raw URL therefore makes the cache miss on every new session: the URL parsed
/// while reading a gallery never matches the one parsed later while
/// downloading it.
///
/// The image's `fileindex` is present in both URL formats and is stable across
/// keystamp rotations, so this extracts it and keys by that. A gallery cached
/// during reading is then reusable by the downloader (and vice versa).
String normalizedImageCacheKey(String url) {
  final Match? fileindex = RegExp(r'fileindex=(\d+)').firstMatch(url);
  if (fileindex != null) {
    return keyToMd5('jh:fi:${fileindex.group(1)}');
  }
  final Match? om = RegExp(r'/om/(\d+)/').firstMatch(url);
  if (om != null) {
    return keyToMd5('jh:fi:${om.group(1)}');
  }
  return keyToMd5(url);
}

/// Finds an image written before stable fileindex cache keys were introduced.
/// When possible it copies that legacy raw-URL entry to the stable key so all
/// later readers, downloads and LAN peers can reuse it.
Future<File?> findCompatibleImageCacheFile({
  required String directory,
  required String url,
}) async {
  final String stableKey = normalizedImageCacheKey(url);
  final File stable = File(path.join(directory, stableKey));
  if (await stable.exists()) {
    return stable;
  }

  final String legacyKey = keyToMd5(url);
  if (legacyKey == stableKey) {
    return null;
  }
  final File legacy = File(path.join(directory, legacyKey));
  if (!await legacy.exists()) {
    return null;
  }
  try {
    await legacy.copy(stable.path);
    return stable;
  } on FileSystemException {
    return await stable.exists() ? stable : legacy;
  }
}
