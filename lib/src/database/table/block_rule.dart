import 'package:drift/drift.dart';

@TableIndex(name: 'idx_group_id', columns: {#groupId})
@TableIndex(name: 'idx_target', columns: {#target})
class BlockRule extends Table {
  @override
  String? get tableName => 'block_rule';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get groupId => text()();

  IntColumn get target => integer()();

  IntColumn get attribute => integer()();

  IntColumn get pattern => integer()();

  TextColumn get expression => text()();
}
