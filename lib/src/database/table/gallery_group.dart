import 'package:drift/drift.dart';

class GalleryGroup extends Table {
  @override
  String? get tableName => 'gallery_group';

  TextColumn get groupName => text().named('groupName')();

  IntColumn get sortOrder => integer().named('sortOrder').withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {groupName};
}
