import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/utils/snack_util.dart';

import '../../../../service/local_block_rule_service.dart';
import 'blocking_rule_page_state.dart';

class BlockingRulePageLogic extends GetxController {
  final String bodyId = 'bodyId';

  final BlockingRulePageState state = BlockingRulePageState();

  final LocalBlockRuleService localBlockRuleService = Get.find();

  @override
  void onReady() {
    getBlockRules();
    super.onReady();
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
