import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/storage_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/snack_util.dart';

import '../../../../service/local_block_rule_service.dart';
import 'blocking_rule_page_state.dart';

class BlockingRulePageLogic extends GetxController {
  final String bodyId = 'bodyId';

  final BlockingRulePageState state = BlockingRulePageState();

  final StorageService storageService = Get.find();
  final LocalBlockRuleService localBlockRuleService = Get.find();

  @override
  void onInit() {
    state.showGroup = storageService.read('displayBlockingRulesGroup') ?? false;
    super.onInit();
  }

  @override
  void onReady() {
    getBlockRules();
    super.onReady();
  }

  void toggleShowGroup() {
    state.showGroup = !state.showGroup;
    updateSafely([bodyId]);

    storageService.write(StorageEnum.displayBlockingRulesGroup.key, state.showGroup);
  }

  void toggleDisplayGroups(String groupName) {
    state.groupedListController.toggleGroup(groupName);
  }

  Future<void> getBlockRules() async {
    List<LocalBlockRule> rules = await localBlockRuleService.getBlockRules();
    rules.sort((a, b) {
      if (a.target.code - b.target.code != 0) {
        return a.target.code - b.target.code;
      }
      if (a.attribute.code - b.attribute.code != 0) {
        return a.attribute.code - b.attribute.code;
      }
      if (a.pattern.code - b.pattern.code != 0) {
        return a.pattern.code - b.pattern.code;
      }
      return a.expression.compareTo(b.expression);
    });

    state.groupedRules = rules.groupListsBy((rule) => rule.groupId!);
    List<String> keys = state.groupedRules.keys.toList();
    keys.sort((a, b) {
      int code = state.groupedRules[a]!.first.target.code - state.groupedRules[b]!.first.target.code;
      if (code != 0) {
        return code;
      }
      return state.groupedRules[b]!.length - state.groupedRules[a]!.length;
    });
    state.groupedRules = LinkedHashMap.fromIterable(
      keys,
      key: (k) => k,
      value: (k) => state.groupedRules[k]!,
    );

    updateSafely([bodyId]);
  }

  Future<void> removeLocalBlockRulesByGroupId(String groupId) async {
    ({bool success, String? msg}) result = await localBlockRuleService.removeLocalBlockRulesByGroupId(groupId);
    if (!result.success) {
      snack('removeBlockRuleFailed'.tr, result.msg ?? '');
    }
  }
}
