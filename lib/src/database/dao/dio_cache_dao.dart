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

  /// Total bytes occupied by the cached page bodies and headers.
  static Future<int> getTotalSize() {
    return appDb
        .customSelect('SELECT COALESCE(SUM(LENGTH(content) + LENGTH(headers)), 0) AS total FROM dio_cache')
        .getSingle()
        .then((row) => row.read<int>('total'));
  }

  /// Lightweight page-cache listing for eviction: keys, URLs, expiry and
  /// sizes without loading the stored bodies.
  static Future<List<DioCachePageInfo>> selectAllWithSize() {
    return appDb
        .customSelect(
          'SELECT cacheKey, url, expireDate, '
          'LENGTH(content) + LENGTH(headers) AS sizeBytes FROM dio_cache',
        )
        .get()
        .then((rows) => rows
            .map((row) => DioCachePageInfo(
                  cacheKey: row.read<String>('cacheKey'),
                  url: row.read<String>('url'),
                  expireDate: DateTime.fromMillisecondsSinceEpoch(
                      row.read<int>('expireDate') * 1000),
                  sizeBytes: row.read<int>('sizeBytes'),
                ))
            .toList());
  }
}

class DioCachePageInfo {
  final String cacheKey;
  final String url;
  final DateTime expireDate;
  final int sizeBytes;

  const DioCachePageInfo({
    required this.cacheKey,
    required this.url,
    required this.expireDate,
    required this.sizeBytes,
  });
}
