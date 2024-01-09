import 'package:drift/drift.dart';

import '../database.dart';

class GalleryImageDao {
  static Future<int> resetImageUrl(int gid, int imageIndex) {
    return (appDb.update(appDb.image)..where((tbl) => tbl.gid.equals(gid) & tbl.serialNo.equals(imageIndex))).write(const ImageCompanion(url: Value.absent()));
  }

  static Future<int> deleteImage(int gid, int imageIndex) {
    return (appDb.delete(appDb.image)..where((tbl) => tbl.gid.equals(gid) & tbl.serialNo.equals(imageIndex))).go();
  }
}
