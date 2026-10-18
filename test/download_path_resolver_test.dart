import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/gallery_download/download_path_resolver.dart';

void main() {
  group('legacy gallery restore path', () {
    test('uses the old 85-character truncation rule', () {
      const String rawTitle =
          '[Papaya Milk (Judith)] Maonaho ~Zenpen~ Maou o Mezasu Otouto ga Ore no Nama Onaho ni Natta Wake [Chinese]';

      final String legacy = DownloadPathResolver.computeLegacySanitizedGalleryTitle(rawTitle);

      expect(legacy.length, lessThanOrEqualTo(DownloadPathResolver.legacyGalleryTitleMaxChars));
      expect(legacy, endsWith('Ore no Nama Onaho ni'));
      expect(rawTitle.startsWith(legacy), isTrue);
    });

    test('prefers the scanned on-disk directory over a newer persisted title', () {
      const int gid = 2059582;
      const String rawTitle =
          '[Papaya Milk (Judith)] Maonaho ~Zenpen~ Maou o Mezasu Otouto ga Ore no Nama Onaho ni Natta Wake [Chinese]';
      final String legacy = DownloadPathResolver.computeLegacySanitizedGalleryTitle(rawTitle);
      final int reservedBytes = utf8.encode('$gid - ').length;
      final String newer = DownloadPathResolver.computeSanitizedGalleryTitle(rawTitle, reservedBytes);

      expect(newer, isNot(legacy));

      final String resolved = DownloadPathResolver.resolveSanitizedGalleryTitleForRestore(
        gid: gid,
        rawTitle: rawTitle,
        persistedSanitizedTitle: newer,
        galleryDirectoryPath: '/storage/emulated/0/JHenTai/download/$gid - $legacy',
      );

      expect(resolved, legacy);
    });

    test('falls back to legacy naming when old metadata is in a non-standard directory', () {
      const int gid = 2059582;
      const String rawTitle =
          '[Papaya Milk (Judith)] Maonaho ~Zenpen~ Maou o Mezasu Otouto ga Ore no Nama Onaho ni Natta Wake [Chinese]';
      final String legacy = DownloadPathResolver.computeLegacySanitizedGalleryTitle(rawTitle);

      final String resolved = DownloadPathResolver.resolveSanitizedGalleryTitleForRestore(
        gid: gid,
        rawTitle: rawTitle,
        persistedSanitizedTitle: null,
        galleryDirectoryPath: '/storage/emulated/0/JHenTai/download/legacy-backup',
      );

      expect(resolved, legacy);
    });
  });

  group('legacy archive restore path', () {
    const String rawTitle =
        '[Papaya Milk (Judith)] Maonaho ~Zenpen~ Maou o Mezasu Otouto ga Ore no Nama Onaho ni Natta Wake [Chinese]';

    test('uses the old 80-character truncation rule', () {
      final String legacy = DownloadPathResolver.computeLegacyArchiveTitle(rawTitle);

      expect(legacy.length, lessThanOrEqualTo(DownloadPathResolver.legacyArchiveTitleMaxChars));
      expect(legacy, startsWith('[Papaya Milk (Judith)]'));
      expect(rawTitle.startsWith(legacy), isTrue);
    });

    test('prefers the scanned unpacking directory over a newer persisted title', () {
      const int gid = 2059582;
      final String legacy = DownloadPathResolver.computeLegacyArchiveTitle(rawTitle);

      expect(rawTitle, isNot(legacy));

      final String resolved = DownloadPathResolver.resolveArchiveSanitizedTitleForRestore(
        gid: gid,
        rawTitle: rawTitle,
        persistedSanitizedTitle: rawTitle,
        archiveDirectoryPath: '/storage/emulated/0/JHenTai/download/Archive - $gid - $legacy',
      );

      expect(resolved, legacy);
    });

    test('falls back to legacy naming when old metadata is in a non-standard directory', () {
      const int gid = 2059582;
      final String legacy = DownloadPathResolver.computeLegacyArchiveTitle(rawTitle);

      final String resolved = DownloadPathResolver.resolveArchiveSanitizedTitleForRestore(
        gid: gid,
        rawTitle: rawTitle,
        persistedSanitizedTitle: null,
        archiveDirectoryPath: '/storage/emulated/0/JHenTai/download/manual-backup-folder',
      );

      expect(resolved, legacy);
    });
  });
}
