import 'package:drift/drift.dart';

@TableIndex(name: 'idx_expire_date', columns: {#expireDate})
@TableIndex(name: 'idx_url', columns: {#url})
class DioCache extends Table {
  @override
  String? get tableName => 'dio_cache';

  TextColumn get cacheKey => text().named('cacheKey')();

  TextColumn get url => text().named('url')();

  DateTimeColumn get expireDate => dateTime().named('expireDate')();

  BlobColumn get content => blob().named('content')();

  BlobColumn get headers => blob().named('headers')();

  @override
  Set<Column<Object>>? get primaryKey => {cacheKey};
}
