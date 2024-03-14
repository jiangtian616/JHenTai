import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class DioCacheDao {
  static Future<DioCacheData?> selectByCacheKey(String cacheKey) {
    return (appDb.select(appDb.dioCache)..where((tbl) => tbl.cacheKey.equals(cacheKey))).getSingleOrNull();
  }

  static Future<int> insertCache(DioCacheData data) {
    return appDb.into(appDb.dioCache).insert(data);
  }

  static Future<int> upsertCache(DioCacheData data) {
    return appDb.into(appDb.dioCache).insertOnConflictUpdate(data);
  }

  static Future<int> deleteByCacheKey(String cacheKey) {
    return (appDb.delete(appDb.dioCache)..where((tbl) => tbl.cacheKey.equals(cacheKey))).go();
  }

  static Future<int> deleteCacheByDate(DateTime date) {
    return (appDb.delete(appDb.dioCache)..where((tbl) => tbl.expireDate.isSmallerThanValue(date))).go();
  }

  static Future<int> deleteCacheLikeUrl(String url) {
    return (appDb.delete(appDb.dioCache)..where((tbl) => tbl.url.like(url))).go();
  }

  static Future<int> deleteAllCache() {
    return appDb.delete(appDb.dioCache).go();
  }
}
