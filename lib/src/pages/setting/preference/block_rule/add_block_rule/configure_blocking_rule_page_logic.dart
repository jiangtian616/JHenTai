import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../../../service/local_block_rule_service.dart';
import '../../../../../utils/snack_util.dart';
import '../../../../../utils/string_uril.dart';
import '../../../../../utils/toast_util.dart';
import 'configure_blocking_rule_page_state.dart';

enum ConfigureBlockingRulePageMode {
  add,
  edit;
}

class ConfigureBlockingRulePageArgument {
  final ConfigureBlockingRulePageMode mode;
  final LocalBlockRule? rule;

  const ConfigureBlockingRulePageArgument({required this.mode, this.rule}) : assert(mode == ConfigureBlockingRulePageMode.add || rule != null);
}

class ConfigureBlockingRulePageLogic extends GetxController {
  final String bodyId = 'bodyId';

  final ConfigureBlockingRulePageState state = ConfigureBlockingRulePageState();

  final LocalBlockRuleService localBlockRuleService = Get.find();

  @override
  void onInit() {
    ConfigureBlockingRulePageArgument argument = Get.arguments;
    if (argument.rule != null) {
      state.ruleId = argument.rule!.id;
      state.blockTargetEnum = argument.rule!.target;
      state.blockAttributeEnum = argument.rule!.attribute;
      state.blockPatternEnum = argument.rule!.pattern;
      state.blockingExpression = argument.rule!.expression;
      state.textEditingController.text = argument.rule!.expression;
    }
    super.onInit();
  }

  Future<void> upsertBlockRule() async {
    if (state.blockTargetEnum == null || state.blockAttributeEnum == null || state.blockPatternEnum == null || isEmptyOrNull(state.blockingExpression)) {
      toast('incompleteInformation'.tr);
      return;
    }

    ({bool success, String? msg}) result = await localBlockRuleService.upsertBlockRule(
      LocalBlockRule(
        id: state.ruleId,
        target: state.blockTargetEnum!,
        attribute: state.blockAttributeEnum!,
        pattern: state.blockPatternEnum!,
        expression: state.blockingExpression!,
      ),
    );

    if (result.success) {
      backRoute(currentRoute: Routes.configureBlockingRules);
    } else {
      snack('configureBlockRuleFailed'.tr, result.msg ?? '');
    }
  }
}
