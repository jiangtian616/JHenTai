import 'package:drift/drift.dart';

class TagCount extends Table {
  @override
  String? get tableName => 'tag_count';

  TextColumn get namespaceWithKey => text().named('namespaceWithKey')();

  IntColumn get count => integer().named('count')();

  @override
  Set<Column<Object>>? get primaryKey => {namespaceWithKey};
}
