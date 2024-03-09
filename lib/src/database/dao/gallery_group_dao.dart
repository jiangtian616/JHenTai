import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class GalleryGroupDao {
  static Future<List<GalleryGroupData>> selectGalleryGroups() {
    return (appDb.select(appDb.galleryGroup)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();
  }

  static Future<int> insertGalleryGroup(GalleryGroupData galleryGroupData) {
    return appDb.into(appDb.galleryGroup).insert(galleryGroupData, mode: InsertMode.insertOrIgnore);
  }

  static Future<int> renameGalleryGroup(String oldGroupName, String newGroupName) async {
    return (appDb.update(appDb.galleryGroup)..where((tbl) => tbl.groupName.equals(oldGroupName))).write(GalleryGroupCompanion(groupName: Value(newGroupName)));
  }

  static Future<int> updateGalleryGroupOrder(String groupName, int sortOrder) async {
    return (appDb.update(appDb.galleryGroup)..where((tbl) => tbl.groupName.equals(groupName))).write(GalleryGroupCompanion(sortOrder: Value(sortOrder)));
  }

  static Future<int> deleteGalleryGroup(String groupName) async {
    return (appDb.delete(appDb.galleryGroup)..where((tbl) => tbl.groupName.equals(groupName))).go();
  }
}
