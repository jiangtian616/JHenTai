import 'package:drift/drift.dart';

class SuperResolutionInfo extends Table {
  @override
  String? get tableName => 'super_resolution_info_v2';

  IntColumn get gid => integer()();

  IntColumn get type => integer()();

  IntColumn get status => integer()();

  TextColumn get imageStatuses => text()();

  @override
  Set<Column<Object>>? get primaryKey => {gid, type};
}

class OldSuperResolutionInfo extends Table {
  @override
  String? get tableName => 'super_resolution_info';

  IntColumn get gid => integer()();

  IntColumn get type => integer()();

  IntColumn get status => integer()();

  TextColumn get imageStatuses => text().named('imageStatuses')();

  @override
  Set<Column<Object>>? get primaryKey => {gid};
}
