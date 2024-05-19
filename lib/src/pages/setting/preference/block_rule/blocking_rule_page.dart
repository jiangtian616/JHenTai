import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/setting/preference/block_rule/add_block_rule/configure_blocking_rule_page_logic.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import '../../../../config/ui_config.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_wheel_speed_controller.dart';
import 'blocking_rule_page_logic.dart';
import 'blocking_rule_page_state.dart';

class BlockingRulePage extends StatelessWidget {
  final BlockingRulePageLogic logic = Get.put<BlockingRulePageLogic>(BlockingRulePageLogic());
  final BlockingRulePageState state = Get.find<BlockingRulePageLogic>().state;

  BlockingRulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('blockingRules'.tr),
      ),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<BlockingRulePageLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        controller: state.scrollController,
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.rules.length,
            controller: state.scrollController,
            itemBuilder: (_, int index) => ListTile(
              minLeadingWidth: 60,
              leading: Text(state.rules[index].target.desc.tr, style: const TextStyle(fontSize: 14)),
              title: Text(state.rules[index].attribute.desc.tr),
              subtitle: Text('${state.rules[index].pattern.desc.tr} ${state.rules[index].expression}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note, size: 24),
                    onPressed: () async {
                      toRoute(
                        Routes.configureBlockingRules,
                        arguments: ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.edit, rule: state.rules[index]),
                      )?.then((_) => logic.getBlockRules());
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 24),
                    onPressed: () async {
                      bool? result = await showDialog(context: context, builder: (_) => EHDialog(title: 'delete'.tr + '?'));
                      if (result == true) {
                        await logic.removeLocalBlockRule(state.rules[index].id!);
                        logic.getBlockRules();
                      }
                    },
                  ),
                ],
              ),
              onTap: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (BuildContext _context) => CupertinoActionSheet(
                    actions: <CupertinoActionSheetAction>[
                      CupertinoActionSheetAction(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, color: UIConfig.primaryColor(context)).marginOnly(right: 4),
                            SizedBox(width: 56, child: Text('edit'.tr)),
                          ],
                        ),
                        onPressed: () async {
                          backRoute();
                          toRoute(
                            Routes.configureBlockingRules,
                            arguments: ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.edit, rule: state.rules[index]),
                          )?.then((_) => logic.getBlockRules());
                        },
                      ),
                      CupertinoActionSheetAction(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: UIConfig.alertColor(context)).marginOnly(right: 4),
                            SizedBox(width: 56, child: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context)))),
                          ],
                        ),
                        onPressed: () async {
                          backRoute();
                          await logic.removeLocalBlockRule(state.rules[index].id!);
                          logic.getBlockRules();
                        },
                      ),
                    ],
                    cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
                  ),
                );
              },
            ),
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        toRoute(Routes.configureBlockingRules, arguments: const ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.add))?.then((_) {
          logic.getBlockRules();
        });
      },
    );
  }
}
