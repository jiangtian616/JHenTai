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

  /// Get total cache size in bytes
  static Future<int> getTotalCacheSize() async {
    final result = await appDb.customSelect(
      'SELECT COALESCE(SUM(size), 0) as total FROM dio_cache',
    ).getSingle();
    return result.read<int>('total');
  }

  /// Delete oldest cache entries by total size
  /// Returns the number of entries deleted
  static Future<int> deleteOldestBySize(int bytesToDelete) async {
    // Get entries ordered by expireDate (oldest first)
    final entries = await (appDb.select(appDb.dioCache)
      ..orderBy([(t) => OrderingTerm.asc(t.expireDate)]))
      .get();

    int deletedSize = 0;
    final keysToDelete = <String>[];

    for (final entry in entries) {
      if (deletedSize >= bytesToDelete) break;
      keysToDelete.add(entry.cacheKey);
      deletedSize += entry.size;
    }

    if (keysToDelete.isNotEmpty) {
      return (appDb.delete(appDb.dioCache)
        ..where((t) => t.cacheKey.isIn(keysToDelete)))
        .go();
    }
    return 0;
  }
}
