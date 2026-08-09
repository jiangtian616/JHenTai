import 'dart:io';

import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Verifies that the download path can find the exact file extended_image
/// writes when it displays an image. Both sides key the disk cache by
/// keyToMd5(url) inside the directory returned by
/// getExtendedImageDiskCacheDirectory(), so a cache populated by reading a
/// gallery is reusable by the downloader (unless the URL differs or the file
/// was evicted).
class _FakePathProvider extends PathProviderPlatform {
  final String tempPath;

  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getApplicationCachePath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

void main() {
  tearDown(() => extendedImageDiskCacheDirectory = null);

  test(
    'getCachedImageFile finds the file extended_image writes (default dir)',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'cache_reuse',
      );
      PathProviderPlatform.instance = _FakePathProvider(temp.path);

      const String url = 'https://example.com/0x0/sample.jpg';
      final String key = keyToMd5(url);
      final File cacheFile = File(p.join(temp.path, cacheImageFolderName, key));
      await cacheFile.create(recursive: true);
      await cacheFile.writeAsBytes([1, 2, 3, 4]);

      final File? found = await getCachedImageFile(url);
      expect(found, isNotNull);
      expect(found!.path, cacheFile.path);

      // A different URL resolves to a different key -> miss.
      final File? miss = await getCachedImageFile(
        'https://example.com/0x0/other.jpg',
      );
      expect(miss, isNull);

      await temp.delete(recursive: true);
    },
  );

  test('normalizedImageCacheKey is stable across keystamp, node and URL format', () {
    // The same image fetched at different times can differ in the keystamp,
    // the H@H node, and even switch between the /h/ and /om/ URL formats.
    // Before this fix the raw md5(url) keys (and the /h/-only regex) differed,
    // so the download always missed the cache.
    const String readHUrl =
        'https://mckuhss.pznlnkzwgarc.hath.network/h/5d59b6900d6c28f59482c5d7d5f4574702fc5826-110286-1280-1707-wbp/keystamp=1786151700-8f6851dd1e;fileindex=244549847;xres=1280/txt_1.webp';
    const String downloadHUrl =
        'https://knypagb.aykedkqwmpfe.hath.network:15443/h/5d59b6900d6c28f59482c5d7d5f4574702fc5826-110286-1280-1707-wbp/keystamp=1787000000-abc123;fileindex=244549847;xres=1280/txt_1.webp';
    const String omUrl =
        'https://puzaqhxrbn.hath.network/om/244549847/a74562093c0968440dfe4cee6dfe38045c93e347-864107-3000-4000-jpg/5d59b6900d6c28f59482c5d7d5f4574702fc5826-110286-1280-1707-wbp/1280/qjfzqlm6tagz4121ndy/txt_1.webp';

    // The three URLs are all different raw strings...
    expect({readHUrl, downloadHUrl, omUrl}.length, 3);
    // ...but they all identify the same image (fileindex 244549847).
    final String readKey = normalizedImageCacheKey(readHUrl);
    expect(readKey, normalizedImageCacheKey(downloadHUrl));
    expect(readKey, normalizedImageCacheKey(omUrl));
  });

  test('effectiveEHImageUrl applies the shared EX image-host rewrite', () {
    expect(
      effectiveEHImageUrl('https://s.exhentai.org/images/a.jpg?x=1'),
      'https://ehgt.org/images/a.jpg?x=1',
    );
    expect(
      effectiveEHImageUrl('https://example.com/images/a.jpg'),
      'https://example.com/images/a.jpg',
    );
  });

  test(
    'getCachedImageFile honors the app custom disk cache directory',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'cache_override',
      );
      final String customDir = p.join(
        temp.path,
        'JHTData',
        'temp',
        'image-cache',
      );
      extendedImageDiskCacheDirectory = customDir;

      const String url = 'https://example.com/0x0/sample.jpg';
      final String key = keyToMd5(url);
      final File cacheFile = File(p.join(customDir, key));
      await cacheFile.create(recursive: true);
      await cacheFile.writeAsBytes([1, 2, 3, 4]);

      final File? found = await getCachedImageFile(url);
      expect(found, isNotNull);
      expect(found!.path, cacheFile.path);

      await temp.delete(recursive: true);
    },
  );
}
