import 'package:get/get.dart';
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
    
    storageService.write('displayBlockingRulesGroup', state.showGroup);
  }

  void toggleDisplayGroups(String groupName) {
    state.groupedListController.toggleGroup(groupName);
  }

  Future<void> getBlockRules() async {
    state.rules = await localBlockRuleService.getBlockRules();
    updateSafely([bodyId]);
  }

  Future<void> removeLocalBlockRule(int id) async {
    ({bool success, String? msg}) result = await localBlockRuleService.removeLocalBlockRule(id);
    if (!result.success) {
      snack('removeBlockRuleFailed'.tr, result.msg ?? '');
    }
  }
}
