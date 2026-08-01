import 'dart:convert';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_url.dart';

/// Helper: create a minimal Gallery for testing.
Gallery _createGallery(int gid, {String token = 'abcdef0123'}) {
  return Gallery(
    galleryUrl: GalleryUrl(isEH: true, gid: gid, token: token),
    title: 'Test Gallery $gid',
    category: 'Doujinshi',
    cover: GalleryImage(url: 'https://example.com/cover.jpg'),
    pageCount: 10,
    rating: 4.5,
    hasRated: false,
    language: 'japanese',
    uploader: 'tester',
    publishTime: '2024-01-01 00:00',
    isExpunged: false,
    tags: LinkedHashMap(),
  );
}

/// Simulate the download service's containGallery check.
class _MockDownloadService {
  final Set<int> _downloadedGids = {};

  void add(int gid) => _downloadedGids.add(gid);

  bool containGallery(int gid) => _downloadedGids.contains(gid);
}

/// Simulate the archive download service's containArchive check.
class _MockArchiveService {
  final Set<int> _archiveGids = {};

  void add(int gid) => _archiveGids.add(gid);

  bool containArchive(int gid) => _archiveGids.contains(gid);
}

void main() {
  group('Task 1: Batch download dedup logic', () {
    test('filters out galleries already in download service', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      // Galleries 1 and 2 are already downloaded
      downloadService.add(1);
      downloadService.add(2);

      List<Gallery> allFavorites = [
        _createGallery(1),
        _createGallery(2),
        _createGallery(3),
        _createGallery(4),
      ];

      // Apply the same filter as FavoritePageLogic._runBatchDownload
      List<Gallery> toDownload = allFavorites.where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload.length, 2);
      expect(toDownload[0].gid, 3);
      expect(toDownload[1].gid, 4);
    });

    test('filters out galleries already in archive service', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      // Gallery 3 is already downloaded as archive
      archiveService.add(3);

      List<Gallery> allFavorites = [
        _createGallery(1),
        _createGallery(2),
        _createGallery(3),
      ];

      List<Gallery> toDownload = allFavorites.where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload.length, 2);
      expect(toDownload[0].gid, 1);
      expect(toDownload[1].gid, 2);
    });

    test('filters out galleries in both services', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      downloadService.add(1);
      archiveService.add(2);
      // Gallery 3 is in BOTH (downloaded as gallery AND archive)
      downloadService.add(3);
      archiveService.add(3);

      List<Gallery> allFavorites = [
        _createGallery(1),
        _createGallery(2),
        _createGallery(3),
        _createGallery(4),
      ];

      List<Gallery> toDownload = allFavorites.where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload.length, 1);
      expect(toDownload[0].gid, 4);
    });

    test('returns empty list when all favorites are already downloaded', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      downloadService.add(1);
      archiveService.add(2);

      List<Gallery> allFavorites = [
        _createGallery(1),
        _createGallery(2),
      ];

      List<Gallery> toDownload = allFavorites.where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload, isEmpty);
    });

    test('returns all favorites when none are downloaded', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      List<Gallery> allFavorites = [
        _createGallery(1),
        _createGallery(2),
        _createGallery(3),
      ];

      List<Gallery> toDownload = allFavorites.where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload.length, 3);
    });

    test('handles empty favorites list', () {
      _MockDownloadService downloadService = _MockDownloadService();
      _MockArchiveService archiveService = _MockArchiveService();

      List<Gallery> toDownload = <Gallery>[].where((g) {
        return !downloadService.containGallery(g.gid) &&
            !archiveService.containArchive(g.gid);
      }).toList();

      expect(toDownload, isEmpty);
    });
  });

  group('Task 2: List incremental loading dedup', () {
    /// Replicates BasePageLogic._cleanDuplicateGallery logic.
    /// Compares by galleryUrl.url (String) since GalleryUrl doesn't override ==.
    void cleanDuplicateGallery(
        List<Gallery> existing, List<Gallery> newGallerys) {
      newGallerys.removeWhere((newGallery) =>
          existing.any((e) => e.galleryUrl.url == newGallery.galleryUrl.url));
    }

    test('removes duplicates from new items based on galleryUrl', () {
      List<Gallery> existing = [_createGallery(1), _createGallery(2)];

      List<Gallery> newGallerys = [
        _createGallery(2), // duplicate
        _createGallery(3), // new
        _createGallery(1), // duplicate
        _createGallery(4), // new
      ];

      cleanDuplicateGallery(existing, newGallerys);

      expect(newGallerys.length, 2);
      expect(newGallerys[0].gid, 3);
      expect(newGallerys[1].gid, 4);
    });

    test('keeps all items when no duplicates', () {
      List<Gallery> existing = [_createGallery(1)];

      List<Gallery> newGallerys = [
        _createGallery(2),
        _createGallery(3),
      ];

      cleanDuplicateGallery(existing, newGallerys);

      expect(newGallerys.length, 2);
    });

    test('handles empty new items list', () {
      List<Gallery> existing = [_createGallery(1)];

      List<Gallery> newGallerys = [];

      cleanDuplicateGallery(existing, newGallerys);

      expect(newGallerys, isEmpty);
    });

    test('handles empty existing list', () {
      List<Gallery> existing = [];

      List<Gallery> newGallerys = [
        _createGallery(1),
        _createGallery(2),
      ];

      cleanDuplicateGallery(existing, newGallerys);

      expect(newGallerys.length, 2);
    });

    test('simulates page-by-page loading without duplicates', () {
      // Simulate loading 3 pages of favorites, each with some overlap
      List<Gallery> loadedGallerys = [];

      // Page 1
      List<Gallery> page1 = [_createGallery(1), _createGallery(2)];
      cleanDuplicateGallery(loadedGallerys, page1);
      loadedGallerys.addAll(page1);

      expect(loadedGallerys.length, 2);

      // Page 2 (gallery 2 appears again as boundary item)
      List<Gallery> page2 = [_createGallery(2), _createGallery(3), _createGallery(4)];
      cleanDuplicateGallery(loadedGallerys, page2);
      loadedGallerys.addAll(page2);

      expect(loadedGallerys.length, 4);
      expect(loadedGallerys.map((g) => g.gid).toList(), [1, 2, 3, 4]);

      // Page 3 (galleries 3 and 5)
      List<Gallery> page3 = [_createGallery(3), _createGallery(5)];
      cleanDuplicateGallery(loadedGallerys, page3);
      loadedGallerys.addAll(page3);

      expect(loadedGallerys.length, 5);
      expect(loadedGallerys.map((g) => g.gid).toList(), [1, 2, 3, 4, 5]);
    });
  });

  group('Task 3: Gallery serialization for batch download resume', () {
    test('Gallery.toJson and fromJson preserve gid', () {
      Gallery original = _createGallery(123456);

      Map<String, dynamic> json = original.toJson();
      Gallery restored = Gallery.fromJson(json);

      expect(restored.gid, original.gid);
      expect(restored.token, original.token);
      expect(restored.galleryUrl.url, original.galleryUrl.url);
    });

    test('Gallery list serialization roundtrip preserves gids', () {
      List<Gallery> originals = [
        _createGallery(100),
        _createGallery(200),
        _createGallery(300),
      ];

      // Serialize list (as in _saveFavorites): use jsonEncode for proper JSON
      String json =
          jsonEncode(originals.map((g) => g.toJson()).toList());

      // Deserialize list (as in _loadFavorites)
      List<dynamic> list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      List<Gallery> restored =
          list.map((e) => Gallery.fromJson(e)).toList();

      expect(restored.length, 3);
      expect(restored[0].gid, 100);
      expect(restored[1].gid, 200);
      expect(restored[2].gid, 300);
    });

    test('batch download progress JSON roundtrip', () {
      // Simulate _saveProgress / _loadProgress
      Map<String, dynamic> progress = {
        'phase': 'loadingFavorites',
        'lastUpdateTime': DateTime.now().toIso8601String(),
        'failureTime': null,
        'targetGroup': 'default',
        'downloadOriginalImage': false,
        'nextGid': '123456/abcdef0123',
      };

      String json = jsonEncode(progress);
      Map<String, dynamic> restored =
          jsonDecode(json) as Map<String, dynamic>;

      expect(restored['phase'], 'loadingFavorites');
      expect(restored['targetGroup'], 'default');
      expect(restored['downloadOriginalImage'], false);
      expect(restored['nextGid'], '123456/abcdef0123');
    });

    test('resume timeout check: within 30 minutes', () {
      DateTime lastUpdateTime = DateTime.now();
      Duration resumeTimeout = const Duration(minutes: 30);

      // Just now → can resume
      bool canResume =
          DateTime.now().difference(lastUpdateTime) < resumeTimeout;
      expect(canResume, true);

      // 31 minutes ago → cannot resume
      DateTime oldTime =
          DateTime.now().subtract(const Duration(minutes: 31));
      canResume = DateTime.now().difference(oldTime) < resumeTimeout;
      expect(canResume, false);
    });
  });
}
