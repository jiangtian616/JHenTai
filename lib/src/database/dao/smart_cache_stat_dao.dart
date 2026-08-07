import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class SmartCacheStatDao {
  static Future<SmartCacheStatData?> selectByKey(String cacheKey) {
    return (appDb.select(appDb.smartCacheStat)
          ..where((tbl) => tbl.cacheKey.equals(cacheKey)))
        .getSingleOrNull();
  }

  static Future<List<SmartCacheStatData>> selectAll() {
    return appDb.select(appDb.smartCacheStat).get();
  }

  static Future<int> upsert(SmartCacheStatData data) {
    return appDb.into(appDb.smartCacheStat).insertOnConflictUpdate(data);
  }

  static Future<int> deleteByKey(String cacheKey) {
    return (appDb.delete(appDb.smartCacheStat)
          ..where((tbl) => tbl.cacheKey.equals(cacheKey)))
        .go();
  }

  static Future<int> deleteByKeys(List<String> cacheKeys) {
    return (appDb.delete(appDb.smartCacheStat)
          ..where((tbl) => tbl.cacheKey.isIn(cacheKeys)))
        .go();
  }

  static Future<int> deleteLikeUrl(String url) {
    return (appDb.delete(appDb.smartCacheStat)
          ..where((tbl) => tbl.url.like(url)))
        .go();
  }

  static Future<int> deleteAll() {
    return appDb.delete(appDb.smartCacheStat).go();
  }

  static Future<int> deleteByKind(String kind) {
    return (appDb.delete(appDb.smartCacheStat)
          ..where((tbl) => tbl.kind.equals(kind)))
        .go();
  }

  /// Records a cache hit, creating a placeholder row if the entry predates
  /// statistics tracking.
  static Future<void> recordHit(
    String cacheKey, {
    String kind = 'page',
    String url = '',
    int sizeBytes = 0,
  }) async {
    final SmartCacheStatData? existing = await selectByKey(cacheKey);
    final DateTime now = DateTime.now();
    if (existing == null) {
      await upsert(SmartCacheStatData(
        cacheKey: cacheKey,
        kind: kind,
        url: url,
        addedAt: now,
        lastAccessAt: now,
        accessCount: 1,
        sizeBytes: sizeBytes,
      ));
    } else {
      await upsert(existing.copyWith(
        lastAccessAt: now,
        accessCount: existing.accessCount + 1,
      ));
    }
  }

  /// Records a newly written cache entry (or refreshes an existing one).
  static Future<void> recordWritten(
    String cacheKey, {
    required String kind,
    required String url,
    required int sizeBytes,
  }) async {
    final SmartCacheStatData? existing = await selectByKey(cacheKey);
    final DateTime now = DateTime.now();
    await upsert(SmartCacheStatData(
      cacheKey: cacheKey,
      kind: kind,
      url: url,
      addedAt: existing?.addedAt ?? now,
      lastAccessAt: now,
      accessCount: (existing?.accessCount ?? 0) + 1,
      sizeBytes: sizeBytes,
    ));
  }
}
