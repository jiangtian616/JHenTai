import 'package:drift/drift.dart';

import '../database.dart';

class GalleryDao {
  static Future<int> insertGalleryGroup(String groupName) {
    return appDb.into(appDb.galleryGroup).insert(
          GalleryGroupData(groupName: groupName, sortOrder: 0),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
