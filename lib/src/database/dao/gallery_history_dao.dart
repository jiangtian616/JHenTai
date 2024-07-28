import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class GalleryHistoryDao {
  static Future<int> selectTotalCount() {
    return appDb.galleryHistoryV2.count().getSingle();
  }

  static Future<List<GalleryHistoryV2Data>> selectAll() {
    return (appDb.select(appDb.galleryHistoryV2)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastReadTime, mode: OrderingMode.asc),
            (tbl) => OrderingTerm(expression: tbl.gid, mode: OrderingMode.asc),
          ]))
        .get();
  }

  static Future<List<GalleryHistoryV2Data>> selectByPageIndex(int pageIndex, int pageSize) {
    return (appDb.select(appDb.galleryHistoryV2)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastReadTime, mode: OrderingMode.desc),
            (tbl) => OrderingTerm(expression: tbl.gid, mode: OrderingMode.desc),
          ])
          ..limit(pageSize, offset: pageIndex * pageSize))
        .get();
  }

  static Future<int> replaceHistory(GalleryHistoryV2Data history) {
    return appDb.into(appDb.galleryHistoryV2).insertOnConflictUpdate(history);
  }

  static Future<void> batchReplaceHistory(List<GalleryHistoryV2Data> histories) async {
    if (histories.isEmpty) {
      return;
    }

    return appDb.batch((batch) {
      return batch.insertAllOnConflictUpdate(appDb.galleryHistoryV2, histories);
    });
  }

  static Future<int> deleteHistory(int gid) {
    return (appDb.delete(appDb.galleryHistoryV2)..where((tbl) => tbl.gid.equals(gid))).go();
  }

  static Future<int> deleteAllHistory() {
    return appDb.delete(appDb.galleryHistoryV2).go();
  }

  static Future<int> selectTotalCountOld() {
    return appDb.galleryHistory.count().getSingle();
  }

  static Future<List<GalleryHistoryData>> selectLargerThanLastReadTimeAndGidOld(String lastReadTime, int gid, int limit) {
    return (appDb.select(appDb.galleryHistory)
          ..where((tbl) => tbl.lastReadTime.isBiggerOrEqualValue(lastReadTime))
          ..where((tbl) => tbl.gid.isBiggerThanValue(gid))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.lastReadTime, mode: OrderingMode.asc),
            (tbl) => OrderingTerm(expression: tbl.gid, mode: OrderingMode.asc),
          ])
          ..limit(limit))
        .get();
  }

  static Future<void> batchDeleteHistoryByGidOld(List<int> gids) {
    return appDb.batch((batch) {
      batch.deleteWhere(appDb.galleryHistory, (tbl) => tbl.gid.isIn(gids));
    });
  }

  static Future<int> deleteAllHistoryOld() {
    return appDb.delete(appDb.galleryHistory).go();
  }
}
