import 'package:drift/drift.dart';

import '../database.dart';

class ArchiveDao {
  static Future<int> insertArchiveGroup(String groupName) {
    return appDb.into(appDb.archiveGroup).insert(
          ArchiveGroupData(groupName: groupName, sortOrder: 0),
          mode: InsertMode.insertOrIgnore,
        );
  }
}
