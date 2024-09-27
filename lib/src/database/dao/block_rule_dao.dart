import '../database.dart';

class BlockRuleDao {
  static Future<List<BlockRuleData>> selectBlockRules() {
    return (appDb.select(appDb.blockRule)).get();
  }

  static Future<List<BlockRuleData>> selectBlockRulesByTarget(int target) {
    return (appDb.select(appDb.blockRule)..where((r) => r.target.equals(target))).get();
  }

  static Future<int> insertBlockRule(BlockRuleCompanion rule) {
    return appDb.into(appDb.blockRule).insert(rule);
  }

  static Future<int> upsertBlockRule(BlockRuleCompanion rule) {
    return appDb.into(appDb.blockRule).insertOnConflictUpdate(rule);
  }

  static Future<int> deleteBlockRuleByGroupId(String groupId) {
    return (appDb.delete(appDb.blockRule)..where((r) => r.groupId.equals(groupId))).go();
  }

  static Future<bool> existsGroup(String groupId) {
    return (appDb.select(appDb.blockRule)..where((r) => r.groupId.equals(groupId))).get().then((value) => value.isNotEmpty);
  }
}
