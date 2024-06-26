import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class GalleryHistoryDao {
  static Future<int> selectTotalCount() {
    return appDb.galleryHistory.count().getSingle();
  }

  static Future<List<GalleryHistoryData>> selectAll() {
    return (appDb.select(appDb.galleryHistory)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastReadTime, mode: OrderingMode.asc),
            (tbl) => OrderingTerm(expression: tbl.gid, mode: OrderingMode.asc),
          ]))
        .get();
  }

  static Future<List<GalleryHistoryData>> selectByPageIndex(int pageIndex, int pageSize) {
    return (appDb.select(appDb.galleryHistory)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastReadTime, mode: OrderingMode.desc),
            (tbl) => OrderingTerm(expression: tbl.gid, mode: OrderingMode.desc),
          ])
          ..limit(pageSize, offset: pageIndex * pageSize))
        .get();
  }

  static Future<int> insertHistory(GalleryHistoryData history) {
    return appDb.into(appDb.galleryHistory).insert(history);
  }

  static Future<int> replaceHistory(GalleryHistoryData history) {
    return appDb.into(appDb.galleryHistory).insertOnConflictUpdate(history);
  }

  static Future<void> batchReplaceHistory(List<GalleryHistoryCompanion> histories) {
    return appDb.batch((batch) {
      return batch.insertAllOnConflictUpdate(appDb.galleryHistory, histories);
    });
  }

  static Future<int> updateHistory(GalleryHistoryCompanion history) {
    return (appDb.update(appDb.galleryHistory)..where((tbl) => tbl.gid.equals(history.gid.value))).write(history);
  }

  static Future<void> batchUpdateHistory(List<GalleryHistoryCompanion> histories) {
    return appDb.batch((batch) {
      for (var history in histories) {
        batch.update(appDb.galleryHistory, history, where: (tbl) => tbl.gid.equals(history.gid.value));
      }
    });
  }

  static Future<int> deleteHistory(int gid) {
    return (appDb.delete(appDb.galleryHistory)..where((tbl) => tbl.gid.equals(gid))).go();
  }

  static Future<int> deleteAllHistory() {
    return appDb.delete(appDb.galleryHistory).go();
  }
}
