import 'package:drift/drift.dart';

import '../database.dart';

class GalleryDao {
  static Future<List<GalleryDownloadedData>> selectGallerys() {
    return appDb.select(appDb.galleryDownloaded).get();
  }

  static Future<List<GalleryDownloadedData>> selectGallerysForTagRefresh(int pageNo, int pageSize) {
    return (appDb.select(appDb.galleryDownloaded)
          ..orderBy([(gallery) => OrderingTerm(expression: gallery.tagRefreshTime)])
          ..limit(pageSize, offset: (pageNo - 1) * pageSize))
        .get();
  }

  static Future<int> insertGallery(GalleryDownloadedCompanion gallery) {
    return appDb.into(appDb.galleryDownloaded).insert(gallery);
  }

  static Future<int> updateGallery(GalleryDownloadedCompanion gallery) {
    return (appDb.update(appDb.galleryDownloaded)..where((a) => a.gid.equals(gallery.gid.value))).write(gallery);
  }

  static Future<int> updateGalleryTags(int gid, String tags) {
    return (appDb.update(appDb.galleryDownloaded)..where((g) => g.gid.equals(gid))).write(
      GalleryDownloadedCompanion(
        tags: Value(tags),
        tagRefreshTime: Value(DateTime.now().toString()),
      ),
    );
  }

  static Future<void> batchUpdateGallery(List<GalleryDownloadedCompanion> gallerys) {
    return appDb.batch((batch) async {
      for (GalleryDownloadedCompanion gallery in gallerys) {
        batch.update(appDb.galleryDownloaded, gallery, where: (a) => a.gid.equals(gallery.gid.value));
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

  static Future<List<GalleryDownloadedOldData>> selectOldGallerys() {
    return (appDb.select(appDb.galleryDownloadedOld)..orderBy([(gallery) => OrderingTerm(expression: gallery.insertTime)])).get();
  }
}
