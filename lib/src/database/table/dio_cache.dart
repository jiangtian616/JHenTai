import 'package:drift/drift.dart';

@TableIndex(name: 'idx_expire_date', columns: {#expireDate})
@TableIndex(name: 'idx_url', columns: {#url})
@TableIndex(name: 'idx_size', columns: {#size})
class DioCache extends Table {
  @override
  String? get tableName => 'dio_cache';

  TextColumn get cacheKey => text().named('cacheKey')();

  TextColumn get url => text().named('url')();

  DateTimeColumn get expireDate => dateTime().named('expireDate')();

  BlobColumn get content => blob().named('content')();

  BlobColumn get headers => blob().named('headers')();

  /// Size of content in bytes for cache management
  IntColumn get size => integer().named('size').withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {cacheKey};
}
