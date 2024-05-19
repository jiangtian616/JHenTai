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
          padding: const EdgeInsets.only(bottom: 80),
          controller: state.scrollController,
          children: [
            ListTile(
              title: Text('blockingTarget'.tr),
              trailing: DropdownButton<LocalBlockTargetEnum>(
                value: state.blockTargetEnum,
                alignment: Alignment.centerRight,
                onChanged: (LocalBlockTargetEnum? newValue) {
                  state.blockTargetEnum = newValue!;
                  state.blockAttributeEnum = LocalBlockAttributeEnum.withTarget(state.blockTargetEnum).firstOrNull;
                  state.blockPatternEnum = LocalBlockPatternEnum.withAttribute(state.blockAttributeEnum).firstOrNull;
                  logic.updateSafely([logic.bodyId]);
                },
                items: LocalBlockTargetEnum.values
                    .map(
                      (e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              title: Text('blockingAttribute'.tr),
              trailing: DropdownButton<LocalBlockAttributeEnum>(
                value: state.blockAttributeEnum,
                alignment: Alignment.centerRight,
                onChanged: (LocalBlockAttributeEnum? newValue) {
                  state.blockAttributeEnum = newValue!;
                  state.blockPatternEnum = LocalBlockPatternEnum.withAttribute(state.blockAttributeEnum).firstOrNull;
                  logic.updateSafely([logic.bodyId]);
                },
                items: LocalBlockAttributeEnum.withTarget(state.blockTargetEnum)
                    .map(
                      (e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              title: Text('blockingPattern'.tr),
              trailing: DropdownButton<LocalBlockPatternEnum>(
                value: state.blockPatternEnum,
                alignment: Alignment.centerRight,
                onChanged: (LocalBlockPatternEnum? newValue) {
                  state.blockPatternEnum = newValue!;
                  logic.updateSafely([logic.bodyId]);
                },
                items: LocalBlockPatternEnum.withAttribute(state.blockAttributeEnum)
                    .map(
                      (e) => DropdownMenuItem(child: Text(e.desc.tr), value: e, alignment: Alignment.center),
                    )
                    .toList(),
              ),
            ),
            ListTile(
              title: Text('blockingExpression'.tr),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: TextField(
                  controller: state.textEditingController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(isDense: true),
                  onChanged: (text) {
                    state.blockingExpression = text;
                  },
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () => backRoute(currentRoute: Routes.configureBlockingRules), child: Text('cancel'.tr)),
                TextButton(onPressed: logic.upsertBlockRule, child: Text('OK'.tr)),
              ],
            ).marginOnly(top: 12),
          ],
        ),
      ),
    );
  }
}
