import 'package:drift/drift.dart';

@TableIndex(name: 'l_idx_u_time', columns: {#utime})
class LocalConfig extends Table {
  @override
  String? get tableName => 'local_config';

  TextColumn get configKey => text()();

  TextColumn get subConfigKey => text()();

  TextColumn get value => text()();

  TextColumn get utime => text()();

  @override
  Set<Column<Object>>? get primaryKey => {configKey, subConfigKey};
}
