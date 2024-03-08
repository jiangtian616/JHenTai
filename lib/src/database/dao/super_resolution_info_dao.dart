import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class SuperResolutionInfoDao {
  static Future<List<SuperResolutionInfoData>> selectAllSuperResolutionInfo() {
    return (appDb.select(appDb.superResolutionInfo)).get();
  }

  static Future<int> insertSuperResolutionInfo(SuperResolutionInfoData entry) {
    return appDb.into(appDb.superResolutionInfo).insert(entry);
  }

  static Future<int> updateSuperResolutionInfo(SuperResolutionInfoCompanion entry) {
    return (appDb.update(appDb.superResolutionInfo)..where((tbl) => tbl.gid.equals(entry.gid.value) & tbl.type.equals(entry.type.value))).write(entry);
  }

  static Future<int> deleteSuperResolutionInfo(int gid, int type) {
    return (appDb.delete(appDb.superResolutionInfo)..where((tbl) => tbl.gid.equals(gid) & tbl.type.equals(type))).go();
  }

  static Future<List<OldSuperResolutionInfoData>> selectAllOldSuperResolutionInfo() {
    return (appDb.select(appDb.oldSuperResolutionInfo)).get();
  }
}
