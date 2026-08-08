import 'package:drift/drift.dart';
import 'package:jhentai/src/database/database.dart';

class SmartCacheStatDao {
  static Future<List<SmartCacheStatData>> selectAll() {
    return appDb.select(appDb.smartCacheStat).get();
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

  /// Drift stores `DateTime` columns as unix seconds by default (see
  /// `SqlTypeMapping.write`), so raw statements must bind the same format.
  static int _toUnixSeconds(DateTime time) =>
      time.millisecondsSinceEpoch ~/ 1000;

  /// Records a cache hit in a single atomic statement (no select-then-upsert).
  /// On conflict only [lastAccessAt] and [accessCount] are bumped — the
  /// existing kind/url/addedAt/sizeBytes are preserved, since a hit carries no
  /// size information.
  static Future<void> recordHit(
    String cacheKey, {
    String kind = 'page',
    String url = '',
    int sizeBytes = 0,
  }) {
    final int now = _toUnixSeconds(DateTime.now());
    return appDb.customStatement(
      'INSERT INTO smart_cache_stat (cacheKey, kind, url, addedAt, lastAccessAt, accessCount, sizeBytes) '
      'VALUES (?, ?, ?, ?, ?, 1, ?) '
      'ON CONFLICT(cacheKey) DO UPDATE SET '
      'lastAccessAt = excluded.lastAccessAt, accessCount = accessCount + 1',
      [cacheKey, kind, url, now, now, sizeBytes],
    );
  }

  /// Records a newly written cache entry (or refreshes an existing one) in a
  /// single atomic statement. On conflict, addedAt/url/kind of the existing
  /// row are preserved while lastAccessAt, accessCount and sizeBytes are
  /// refreshed.
  static Future<void> recordWritten(
    String cacheKey, {
    required String kind,
    required String url,
    required int sizeBytes,
  }) {
    final int now = _toUnixSeconds(DateTime.now());
    return appDb.customStatement(
      'INSERT INTO smart_cache_stat (cacheKey, kind, url, addedAt, lastAccessAt, accessCount, sizeBytes) '
      'VALUES (?, ?, ?, ?, ?, 1, ?) '
      'ON CONFLICT(cacheKey) DO UPDATE SET '
      'lastAccessAt = excluded.lastAccessAt, accessCount = accessCount + 1, sizeBytes = excluded.sizeBytes',
      [cacheKey, kind, url, now, now, sizeBytes],
    );
  }

  /// Batched variant of [recordHit] used by the image-event aggregation in
  /// SmartCacheService. Each buffered hit count is added in one statement.
  static Future<void> batchRecordHits(Map<String, int> hitCounts) {
    if (hitCounts.isEmpty) {
      return Future<void>.value();
    }
    final int now = _toUnixSeconds(DateTime.now());
    return appDb.transaction(() async {
      await appDb.batch((batch) {
        for (final MapEntry<String, int> entry in hitCounts.entries) {
          batch.customStatement(
            'INSERT INTO smart_cache_stat (cacheKey, kind, url, addedAt, lastAccessAt, accessCount, sizeBytes) '
            'VALUES (?, ?, ?, ?, ?, ?, ?) '
            'ON CONFLICT(cacheKey) DO UPDATE SET '
            'lastAccessAt = excluded.lastAccessAt, accessCount = accessCount + ?',
            [entry.key, 'image', '', now, now, entry.value, 0, entry.value],
          );
        }
      });
    });
  }

  /// Batched variant of [recordWritten] used by the image-event aggregation in
  /// SmartCacheService. The latest observed sizeBytes wins per key.
  static Future<void> batchRecordWrittens(
    Map<String, ({int count, int sizeBytes})> writtenCounts,
  ) {
    if (writtenCounts.isEmpty) {
      return Future<void>.value();
    }
    final int now = _toUnixSeconds(DateTime.now());
    return appDb.transaction(() async {
      await appDb.batch((batch) {
        for (final MapEntry<String, ({int count, int sizeBytes})> entry
            in writtenCounts.entries) {
          batch.customStatement(
            'INSERT INTO smart_cache_stat (cacheKey, kind, url, addedAt, lastAccessAt, accessCount, sizeBytes) '
            'VALUES (?, ?, ?, ?, ?, ?, ?) '
            'ON CONFLICT(cacheKey) DO UPDATE SET '
            'lastAccessAt = excluded.lastAccessAt, accessCount = accessCount + ?, sizeBytes = excluded.sizeBytes',
            [
              entry.key,
              'image',
              entry.key,
              now,
              now,
              entry.value.count,
              entry.value.sizeBytes,
              entry.value.count,
            ],
          );
        }
      });
    });
  }
}
