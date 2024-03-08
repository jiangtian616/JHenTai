import 'package:drift/drift.dart';

@TableIndex(name: 'idx_key', columns: {#key})
@TableIndex(name: 'idx_tagName', columns: {#tagName})
class Tag extends Table {
  @override
  String? get tableName => 'tag';

  TextColumn get namespace => text().named('namespace')();

  @JsonKey('_key')
  TextColumn get key => text().named('_key')();

  TextColumn get translatedNamespace => text().named('translatedNamespace').nullable()();

  TextColumn get tagName => text().named('tagName').nullable()();

  TextColumn get fullTagName => text().named('fullTagName').nullable()();

  TextColumn get intro => text().named('intro').nullable()();

  TextColumn get links => text().named('links').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {namespace, key};
}
