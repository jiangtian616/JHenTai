import 'package:drift/drift.dart';

class SmartCacheStat extends Table {
  TextColumn get cacheKey => text().named('cacheKey')();

  /// 'page' or 'image'
  TextColumn get kind => text().named('kind')();

  TextColumn get url => text().named('url')();

  DateTimeColumn get addedAt => dateTime().named('addedAt')();

  DateTimeColumn get lastAccessAt => dateTime().named('lastAccessAt')();

  IntColumn get accessCount => integer().named('accessCount')();

  IntColumn get sizeBytes => integer().named('sizeBytes')();

  @override
  Set<Column<Object>>? get primaryKey => {cacheKey};
}
