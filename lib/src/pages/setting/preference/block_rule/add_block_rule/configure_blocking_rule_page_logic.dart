import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../../../service/local_block_rule_service.dart';
import '../../../../../utils/snack_util.dart';
import '../../../../../utils/toast_util.dart';
import '../../../../../utils/uuid_util.dart';
import 'configure_blocking_rule_page_state.dart';

enum ConfigureBlockingRulePageMode { add, edit }

class ConfigureBlockingRulePageArgument {
  final ConfigureBlockingRulePageMode mode;
  final ({String groupId, List<LocalBlockRule> rules})? groupRules;

  const ConfigureBlockingRulePageArgument({required this.mode, this.groupRules}) : assert(mode == ConfigureBlockingRulePageMode.add || (groupRules != null));
}

class ConfigureBlockingRulePageLogic extends GetxController {
  final String bodyId = 'bodyId';

  final ConfigureBlockingRulePageState state = ConfigureBlockingRulePageState();

  @override
  void onInit() {
    ConfigureBlockingRulePageArgument argument = Get.arguments;
    if (argument.groupRules == null) {
      state.groupId = newUUID();
      state.rules.add(
        LocalBlockRule(
          target: LocalBlockTargetEnum.gallery,
          attribute: LocalBlockAttributeEnum.title,
          pattern: LocalBlockPatternEnum.like,
          expression: '',
        ),
      );
    } else {
      state.groupId = argument.groupRules!.groupId;
      state.rules.addAll(argument.groupRules!.rules);
    }

    super.onInit();
  }

  Future<void> configureCurrentBlockRulesByGroup() async {
    if (state.rules.isEmpty) {
      toast('noBlockingRuleHint'.tr);
      return;
    }

    if (state.rules.map((rule) => rule.target).toSet().length > 1) {
      toast('notSameBlockingRuleTargetHint'.tr);
      return;
    }

    if (state.rules.any((rule) => rule.expression.isEmpty)) {
      toast('incompleteInformation'.tr);
      return;
    }

    ({bool success, String? msg}) result = await localBlockRuleService.replaceBlockRulesByGroup(state.groupId, state.rules);

    if (result.success) {
      backRoute(currentRoute: Routes.configureBlockingRules);
    } else {
      snack('configureBlockRuleFailed'.tr, result.msg ?? '');
    }
  }

  void addRuleForm() {
    state.rules.add(
      LocalBlockRule(
        target: LocalBlockTargetEnum.gallery,
        attribute: LocalBlockAttributeEnum.title,
        pattern: LocalBlockPatternEnum.like,
        expression: '',
      ),
    );
    updateSafely([bodyId]);
  }

  void removeRuleForm(LocalBlockRule rule) {
    state.rules.remove(rule);
    updateSafely([bodyId]);
  }
}
