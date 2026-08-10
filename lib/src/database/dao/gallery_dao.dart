import 'package:drift/drift.dart';

import '../database.dart';

class GalleryDao {
  static Future<List<GalleryDownloadedData>> selectGalleries() {
    return appDb.select(appDb.galleryDownloaded).get();
  }

  static Future<List<GalleryDownloadedData>> selectGalleriesForTagRefresh(int pageNo, int pageSize) {
    return (appDb.select(appDb.galleryDownloaded)
          ..orderBy([(gallery) => OrderingTerm(expression: gallery.tagRefreshTime)])
          ..limit(pageSize, offset: (pageNo - 1) * pageSize))
        .get();
  }

  static Future<int> insertGallery(GalleryDownloadedCompanion gallery) {
    return appDb.into(appDb.galleryDownloaded).insert(gallery);
  }

  /// Update a single gallery row. When [fromStatusIndex] is provided, the
  /// update is gated on the current `downloadStatusIndex` matching — a CAS
  /// guard preventing a status-flipping path (e.g. reDownloadImage setting
  /// `downloading`) from overwriting a concurrent status change (e.g.
  /// pauseAll setting `paused`). Mirrors [batchUpdateGallery]'s CAS param.
  /// Returns 0 rows updated if the CAS failed.
  static Future<int> updateGallery(GalleryDownloadedCompanion gallery, {int? fromStatusIndex}) {
    final update = appDb.update(appDb.galleryDownloaded);
    if (fromStatusIndex == null) {
      return (update..where((a) => a.gid.equals(gallery.gid.value))).write(gallery);
    }
    return (update
          ..where((a) => a.gid.equals(gallery.gid.value) & a.downloadStatusIndex.equals(fromStatusIndex)))
        .write(gallery);
  }

  static Future<int> updateGalleryTags(int gid, String tags) {
    return (appDb.update(appDb.galleryDownloaded)..where((g) => g.gid.equals(gid))).write(
      GalleryDownloadedCompanion(
        tags: Value(tags),
        tagRefreshTime: Value(DateTime.now().toString()),
      ),
    );
  }

  /// Batch-update gallery rows. When [fromStatusIndex] is provided, each row
  /// is updated only if its current `downloadStatusIndex` matches — a CAS
  /// (compare-and-swap) guard that prevents bulk pause/resume from
  /// overwriting a winning concurrent write (e.g. a download completing →
  /// `downloaded` while pauseAll is mid-transaction). Mirrors the WHERE-
  /// condition pattern used by [GalleryImageDao.updateImageStatusByGids].
  /// Callers that don't touch `downloadStatusIndex` (e.g. tag refresh) omit
  /// it and get an unconditional update on `gid`.
  static Future<void> batchUpdateGallery(
    List<GalleryDownloadedCompanion> galleries, {
    int? fromStatusIndex,
  }) {
    return appDb.batch((batch) async {
      for (GalleryDownloadedCompanion gallery in galleries) {
        if (fromStatusIndex == null) {
          batch.update(appDb.galleryDownloaded, gallery, where: (a) => a.gid.equals(gallery.gid.value));
        } else {
          batch.update(
            appDb.galleryDownloaded,
            gallery,
            where: (a) => a.gid.equals(gallery.gid.value) & a.downloadStatusIndex.equals(fromStatusIndex),
          );
        }
      }
    });
  }

  static Future<int> reGroupGallery(String oldGroupName, String newGroupName) {
    return (appDb.update(appDb.galleryDownloaded)..where((a) => a.groupName.equals(oldGroupName)))
        .write(GalleryDownloadedCompanion(groupName: Value(newGroupName)));
  }

  static Future<int> deleteGallery(int gid) {
    return (appDb.delete(appDb.galleryDownloaded)..where((gallery) => gallery.gid.equals(gid))).go();
  }

  static Future<List<GalleryDownloadedOldData>> selectOldGalleries() {
    return (appDb.select(appDb.galleryDownloadedOld)..orderBy([(gallery) => OrderingTerm(expression: gallery.insertTime)])).get();
  }
}
