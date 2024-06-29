import 'package:drift/drift.dart';

import '../database.dart';

class GalleryDao {
  static Future<List<GalleryDownloadedData>> selectGallerys() {
    return appDb.select(appDb.galleryDownloaded).get();
  }

  static Future<int> insertGallery(GalleryDownloadedCompanion gallery) {
    return appDb.into(appDb.galleryDownloaded).insert(gallery);
  }

  static Future<int> updateGallery(GalleryDownloadedCompanion gallery) {
    return (appDb.update(appDb.galleryDownloaded)..where((a) => a.gid.equals(gallery.gid.value))).write(gallery);
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
