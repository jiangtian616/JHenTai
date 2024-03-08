import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class ArchiveGroupDao {
  static Future<List<ArchiveGroupData>> selectArchiveGroups() {
    return (appDb.select(appDb.archiveGroup)..orderBy([(archive) => OrderingTerm(expression: archive.sortOrder)])).get();
  }

  static Future<int> insertArchiveGroup(ArchiveGroupData archiveGroupData) {
    return appDb.into(appDb.archiveGroup).insert(archiveGroupData, mode: InsertMode.insertOrIgnore);
  }

  static Future<int> renameArchiveGroup(String oldGroupName, String newGroupName) async {
    return (appDb.update(appDb.archiveGroup)..where((tbl) => tbl.groupName.equals(oldGroupName))).write(ArchiveGroupCompanion(groupName: Value(newGroupName)));
  }

  static Future<int> updateArchiveGroupOrder(String groupName, int sortOrder) async {
    return (appDb.update(appDb.archiveGroup)..where((tbl) => tbl.groupName.equals(groupName))).write(ArchiveGroupCompanion(sortOrder: Value(sortOrder)));
  }

  static Future<int> deleteArchiveGroup(String groupName) async {
    return (appDb.delete(appDb.archiveGroup)..where((tbl) => tbl.groupName.equals(groupName))).go();
  }
}
