import '../database.dart';

class BlockRuleDao {
  static Future<List<BlockRuleData>> selectBlockRules() {
    return (appDb.select(appDb.blockRule)).get();
  }

  static Future<List<BlockRuleData>> selectBlockRulesByTarget(int target) {
    return (appDb.select(appDb.blockRule)..where((r) => r.target.equals(target))).get();
  }

  static Future<int> upsertBlockRule(BlockRuleCompanion rule) {
    return appDb.into(appDb.blockRule).insertOnConflictUpdate(rule);
  }

  static Future<int> updateBlockRule(BlockRuleData rule) {
    return (appDb.update(appDb.blockRule)..where((r) => r.id.equals(rule.id))).write(rule);
  }

  static Future<int> deleteBlockRule(int id) {
    return (appDb.delete(appDb.blockRule)..where((r) => r.id.equals(id))).go();
  }
}
