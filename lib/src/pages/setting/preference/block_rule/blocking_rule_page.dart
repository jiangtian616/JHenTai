import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/setting/preference/block_rule/add_block_rule/configure_blocking_rule_page_logic.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/grouped_list.dart';
import '../../../../config/ui_config.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_wheel_speed_controller.dart';
import '../../../download/download_base_page.dart';
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
        actions: [
          IconButton(icon: const Icon(Icons.view_list), onPressed: logic.toggleShowGroup),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<BlockingRulePageLogic>(
      id: logic.bodyId,
      builder: (_) {
        Widget child = state.showGroup
            ? GroupedList<String, LocalBlockRule>(
                maxGalleryNum4Animation: 50,
                scrollController: state.scrollController,
                controller: state.groupedListController,
                groups: Map.fromEntries(state.rules.map((rule) => MapEntry('${rule.target.desc.tr} - ${rule.attribute.desc.tr}', true))),
                elements: state.rules,
                elementGroup: (LocalBlockRule rule) => '${rule.target.desc.tr} - ${rule.attribute.desc.tr}',
                groupBuilder: (context, groupName, isOpen) => _groupBuilder(context, groupName, isOpen).marginAll(5),
                elementBuilder: (BuildContext context, LocalBlockRule rule, isOpen) => _itemBuilder(context, rule),
                groupUniqueKey: (String group) => group,
                elementUniqueKey: (LocalBlockRule rule) => rule.id.toString(),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: state.rules.length,
                controller: state.scrollController,
                itemBuilder: (_, int index) => ListTile(
                  minLeadingWidth: 60,
                  leading: Text(state.rules[index].target.desc.tr, style: const TextStyle(fontSize: 14)),
                  title: Text(state.rules[index].attribute.desc.tr),
                  subtitle: Text('${state.rules[index].pattern.desc.tr} ${state.rules[index].expression}'),
                  trailing: _buildListTileTrailing(context, state.rules[index]),
                  onTap: () => _showOperationBottomSheet(context, state.rules[index]),
                ),
              );

        return EHWheelSpeedController(
          controller: state.scrollController,
          child: SafeArea(child: child..withListTileTheme(context)),
        );
      },
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

  Widget _groupBuilder(BuildContext context, String groupName, bool isOpen) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      child: Container(
        height: UIConfig.groupListHeight,
        decoration: BoxDecoration(
          color: UIConfig.groupListColor(context),
          boxShadow: [if (!Get.isDarkMode) UIConfig.groupListShadow(context)],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GroupOpenIndicator(isOpen: isOpen).marginOnly(right: 8),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, LocalBlockRule rule) {
    return ListTile(
      minLeadingWidth: 40,
      leading: Text(rule.pattern.desc.tr, style: const TextStyle(fontSize: 14)),
      title: Text(rule.expression),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      trailing: _buildListTileTrailing(context, rule),
      onTap: () => _showOperationBottomSheet(context, rule),
    ).paddingSymmetric(horizontal: 5);
  }

  Row _buildListTileTrailing(BuildContext context, LocalBlockRule rule) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note, size: 24),
          onPressed: () async {
            toRoute(
              Routes.configureBlockingRules,
              arguments: ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.edit, rule: rule),
            )?.then((_) => logic.getBlockRules());
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 24),
          onPressed: () async {
            bool? result = await showDialog(context: context, builder: (_) => EHDialog(title: 'delete'.tr + '?'));
            if (result == true) {
              await logic.removeLocalBlockRule(rule.id!);
              logic.getBlockRules();
            }
          },
        ),
      ],
    );
  }

  void _showOperationBottomSheet(BuildContext context, LocalBlockRule rule) {
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
                arguments: ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.edit, rule: rule),
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
              await logic.removeLocalBlockRule(rule.id!);
              logic.getBlockRules();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }
}
