import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../../../service/local_block_rule_service.dart';
import '../../../../../widget/eh_wheel_speed_controller.dart';
import 'configure_blocking_rule_page_logic.dart';
import 'configure_blocking_rule_page_state.dart';

class ConfigureBlockingRulePage extends StatelessWidget {
  final ConfigureBlockingRulePageLogic logic = Get.put<ConfigureBlockingRulePageLogic>(ConfigureBlockingRulePageLogic());
  final ConfigureBlockingRulePageState state = Get.find<ConfigureBlockingRulePageLogic>().state;

  ConfigureBlockingRulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('blockingRules'.tr),
        actions: [
          TextButton(onPressed: logic.configureCurrentBlockRulesByGroup, child: Text('OK'.tr)),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<ConfigureBlockingRulePageLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        controller: state.scrollController,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
          controller: state.scrollController,
          children: [
            ...state.rules.map((rule) => _buildRuleForm(rule).marginOnly(bottom: 12)).toList(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  child: const Icon(Icons.add),
                  style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                  onPressed: logic.addRuleForm,
                ),
              ],
            ).marginOnly(top: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleForm(LocalBlockRule rule) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('blockingTarget'.tr),
                  trailing: DropdownButton<LocalBlockTargetEnum>(
                    value: rule.target,
                    alignment: Alignment.centerRight,
                    onChanged: (LocalBlockTargetEnum? newValue) {
                      rule.target = newValue!;
                      rule.attribute = LocalBlockAttributeEnum.withTarget(rule.target).first;
                      rule.pattern = LocalBlockPatternEnum.withAttribute(rule.attribute).first;
                      logic.updateSafely([logic.bodyId]);
                    },
                    items: LocalBlockTargetEnum.values.map((e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center)).toList(),
                  ),
                ),
                ListTile(
                  title: Text('blockingAttribute'.tr),
                  trailing: DropdownButton<LocalBlockAttributeEnum>(
                    value: rule.attribute,
                    alignment: Alignment.centerRight,
                    onChanged: (LocalBlockAttributeEnum? newValue) {
                      rule.attribute = newValue!;
                      rule.pattern = LocalBlockPatternEnum.withAttribute(rule.attribute).first;
                      logic.updateSafely([logic.bodyId]);
                    },
                    items: LocalBlockAttributeEnum.withTarget(rule.target)
                        .map((e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center))
                        .toList(),
                  ),
                ),
                ListTile(
                  title: Text('blockingPattern'.tr),
                  trailing: DropdownButton<LocalBlockPatternEnum>(
                    value: rule.pattern,
                    alignment: Alignment.centerRight,
                    onChanged: (LocalBlockPatternEnum? newValue) {
                      rule.pattern = newValue!;
                      logic.updateSafely([logic.bodyId]);
                    },
                    items: LocalBlockPatternEnum.withAttribute(rule.attribute)
                        .map((e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center))
                        .toList(),
                  ),
                ),
                ListTile(
                  title: Text('blockingExpression'.tr),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: TextField(
                      controller: TextEditingController(text: rule.expression),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (text) {
                        rule.expression = text;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              child: const Icon(Icons.remove),
              style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
              onPressed: () {
                logic.removeRuleForm(rule);
              },
            ),
          ],
        ),
      ],
    );
  }
}
