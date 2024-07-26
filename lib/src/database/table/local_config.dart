import 'package:drift/drift.dart';

class LocalConfig extends Table {
  @override
  String? get tableName => 'local_config';

  TextColumn get configKey => text()();

  TextColumn get subConfigKey => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>>? get primaryKey => {configKey, subConfigKey};
}
