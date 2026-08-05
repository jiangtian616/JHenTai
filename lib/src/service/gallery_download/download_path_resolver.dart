import 'package:get/get_utils/src/platform/platform.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:path/path.dart' as path;

import '../path_service.dart';

/// Pure path-computation helpers for gallery download storage. No state —
/// all methods are static and read singletons ([downloadSetting], [pathService]).
///
/// Accepts [GalleryDownloadedData] (the DB shape) since path computation is
/// pure and doesn't need runtime state. Callers holding [GalleryDownloadInfo]
/// should convert via `.toGalleryDownloadedData()` at the call site, or use
/// the wrappers on [GalleryDownloadService] which do that automatically.
class DownloadPathResolver {
  static const int maxFileNameBytes = 200;

  /// Compute the sanitized title for the first time. Strips illegal file-name
  /// characters then truncates to fit within [maxFileNameBytes] bytes minus
  /// [reservedBytes] (the byte length of the surrounding prefix).
  static String computeSanitizedGalleryTitle(String rawTitle, int reservedBytes) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();
    return FileUtil.truncateTitleToBytes(title, maxFileNameBytes - reservedBytes);
  }

  /// Directory name format: '{gid} - {title}'
  static String computeGalleryDownloadAbsolutePath(GalleryDownloadedData gallery) {
    return path.join(downloadSetting.downloadPath.value, '${gallery.gid} - ${gallery.sanitizedTitle}');
  }

  static String computeImageDownloadAbsolutePath(GalleryDownloadedData gallery, String imageUrl, int serialNo) {
    /// original image's url doesn't has an ext
    String? ext = imageUrl.contains('fullimg.php') ? 'jpg' : imageUrl.split('.').last;

    return path.join(
      computeGalleryDownloadAbsolutePath(gallery),
      '$serialNo.$ext',
    );
  }

  static String computeImageDownloadRelativePath(GalleryDownloadedData gallery, String imageUrl, int serialNo) {
    return path.relative(
      computeImageDownloadAbsolutePath(gallery, imageUrl, serialNo),
      from: pathService.getVisibleDir().path,
    );
  }

  static String computeImageDownloadAbsolutePathFromRelativePath(String imageRelativePath) {
    String p = path.join(pathService.getVisibleDir().path, imageRelativePath);

    /// I don't know why some images can't be loaded on Windows... If you knows, please tell me
    if (!GetPlatform.isWindows) {
      return p;
    }

    return path.join(path.rootPrefix(p), path.relative(p, from: path.rootPrefix(p)));
  }
}
