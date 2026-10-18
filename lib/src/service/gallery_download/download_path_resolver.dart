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
  static const int legacyGalleryTitleMaxChars = 85;
  static const int legacyArchiveTitleMaxChars = 80;

  /// Compute the sanitized title for the first time. Strips illegal file-name
  /// characters then truncates to fit within [maxFileNameBytes] bytes minus
  /// [reservedBytes] (the byte length of the surrounding prefix).
  static String computeSanitizedGalleryTitle(String rawTitle, int reservedBytes) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();
    return FileUtil.truncateTitleToBytes(title, maxFileNameBytes - reservedBytes);
  }

  /// Reproduce the pre-sanitizedTitle gallery directory naming rule.
  ///
  /// Old releases sanitized illegal characters and then truncated the title to
  /// 85 Dart string characters. Metadata written by those releases has no
  /// `sanitizedTitle`, so using the current byte-based rule while restoring it
  /// can point every image at a directory that never existed on disk.
  static String computeLegacySanitizedGalleryTitle(String rawTitle) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();
    if (title.length > legacyGalleryTitleMaxChars) {
      title = title.substring(0, legacyGalleryTitleMaxChars).trim();
    }
    return title;
  }

  /// Resolve the directory title to use while restoring metadata from disk.
  ///
  /// The directory currently being scanned is the strongest source of truth:
  /// it is where the image bytes actually live. Prefer its `{gid} - {title}`
  /// suffix even when metadata already contains a different `sanitizedTitle`.
  /// This also repairs records that were restored once with the wrong newer
  /// truncation rule. If the directory was renamed to a non-standard shape,
  /// fall back to the persisted value, or finally the legacy 85-char rule for
  /// metadata written before `sanitizedTitle` existed.
  static String resolveSanitizedGalleryTitleForRestore({
    required int gid,
    required String rawTitle,
    required String? persistedSanitizedTitle,
    required String galleryDirectoryPath,
  }) {
    final String directoryName = path.basename(path.normalize(galleryDirectoryPath));
    final String prefix = '$gid - ';
    if (directoryName.startsWith(prefix)) {
      return directoryName.substring(prefix.length);
    }
    return persistedSanitizedTitle ?? computeLegacySanitizedGalleryTitle(rawTitle);
  }

  /// Reproduce the pre-sanitizedTitle archive unpacking-directory naming rule.
  ///
  /// Old releases sanitized illegal characters and then truncated the title to
  /// 80 Dart string characters. Metadata written by those releases has no
  /// `sanitizedTitle`, so using the current byte-based rule while restoring it
  /// can point every image at an unpacking directory that never existed on disk.
  static String computeLegacyArchiveTitle(String rawTitle) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();
    if (title.length > legacyArchiveTitleMaxChars) {
      title = title.substring(0, legacyArchiveTitleMaxChars).trim();
    }
    return title;
  }

  /// Resolve the archive unpacking-directory title to use while restoring
  /// metadata from disk. Same rationale as [resolveSanitizedGalleryTitleForRestore]
  /// but for the `Archive - {gid} - {title}` directory shape: prefer the scanned
  /// directory's own suffix (that is where the unpacked image bytes live), then
  /// the persisted value, and finally the legacy 80-char rule for metadata
  /// written before `sanitizedTitle` existed.
  static String resolveArchiveSanitizedTitleForRestore({
    required int gid,
    required String rawTitle,
    required String? persistedSanitizedTitle,
    required String archiveDirectoryPath,
  }) {
    final String directoryName = path.basename(path.normalize(archiveDirectoryPath));
    final String prefix = 'Archive - $gid - ';
    if (directoryName.startsWith(prefix)) {
      return directoryName.substring(prefix.length);
    }
    return persistedSanitizedTitle ?? computeLegacyArchiveTitle(rawTitle);
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
