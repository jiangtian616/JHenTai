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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          toRoute(Routes.configureBlockingRules, arguments: const ConfigureBlockingRulePageArgument(mode: ConfigureBlockingRulePageMode.add))?.then((_) {
            logic.getBlockRules();
          });
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<BlockingRulePageLogic>(
      id: logic.bodyId,
      builder: (_) {
        Widget child = state.showGroup
            ? GroupedList<String, List<LocalBlockRule>>(
                maxGalleryNum4Animation: 50,
                scrollController: state.scrollController,
                controller: state.groupedListController,
                groups: state.groupedRules.map(
                  (groupId, rules) => MapEntry('${rules.first.target.desc.tr}${rules.length > 1 ? '' : ' - ' + rules.first.attribute.desc.tr}', true),
                ),
                elements: state.groupedRules.values.toList(),
                elementGroup: (List<LocalBlockRule> rules) => '${rules.first.target.desc.tr}${rules.length > 1 ? '' : ' - ' + rules.first.attribute.desc.tr}',
                groupBuilder: (context, group, isOpen) => _groupBuilder(context, group, isOpen).marginAll(5),
                elementBuilder: (BuildContext context, String group, List<LocalBlockRule> rules, isOpen) => _elementBuilder(context, group, rules),
                groupUniqueKey: (String group) => group,
                elementUniqueKey: (List<LocalBlockRule> rules) => rules.first.groupId!,
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: state.groupedRules.keys.length,
                controller: state.scrollController,
                itemBuilder: _itemBuilder,
              );

        return EHWheelSpeedController(
          controller: state.scrollController,
          child: SafeArea(child: child..withListTileTheme(context)),
        );
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
            const SizedBox(width: 16),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GroupOpenIndicator(isOpen: isOpen).marginOnly(right: 8),
          ],
        ),
      ),
    );
  }

  Widget _elementBuilder(BuildContext context, String group, List<LocalBlockRule> rules) {
    return ListTile(
      minLeadingWidth: 60,
      leading: Text(rules.length == 1 ? rules.first.pattern.desc.tr : 'other'.tr, style: const TextStyle(fontSize: 14)),
      title: Text(
        rules.length == 1 ? rules.first.expression : rules.map((rule) => '(${rule.attribute.desc.tr} ${rule.pattern.desc.tr} ${rule.expression})').join(' && '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      trailing: _buildListTileTrailing(context, rules.first.groupId!, rules),
      contentPadding: const EdgeInsets.only(left: 16),
      onTap: () => _showOperationBottomSheet(context, rules.first.groupId!, rules),
    ).paddingSymmetric(horizontal: 4);
  }

  Widget _itemBuilder(BuildContext context, int index) {
    MapEntry<String, List<LocalBlockRule>> entry = state.groupedRules.entries.toList()[index];

    return ListTile(
      minLeadingWidth: 70,
      leading: Text(entry.value.first.target.desc.tr, style: const TextStyle(fontSize: 14)),
      title: Text(
        entry.value.map((rule) => rule.attribute.desc.tr).join('+'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.value.map((rule) => '(${rule.attribute.desc.tr} ${rule.pattern.desc.tr} ${rule.expression})').join(' && '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildListTileTrailing(context, entry.key, entry.value),
      onTap: () => _showOperationBottomSheet(context, entry.key, entry.value),
    );
  }

  Row _buildListTileTrailing(BuildContext context, String groupId, List<LocalBlockRule> rules) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note, size: 24),
          onPressed: () async {
            toRoute(
              Routes.configureBlockingRules,
              arguments: ConfigureBlockingRulePageArgument(
                mode: ConfigureBlockingRulePageMode.edit,
                groupRules: (groupId: groupId, rules: rules),
              ),
            )?.then((_) => logic.getBlockRules());
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 24),
          onPressed: () async {
            bool? result = await showDialog(context: context, builder: (_) => EHDialog(title: 'delete'.tr + '?'));
            if (result == true) {
              await logic.removeLocalBlockRulesByGroupId(groupId);
              logic.getBlockRules();
            }
          },
        ),
      ],
    );
  }

  void _showOperationBottomSheet(BuildContext context, String groupId, List<LocalBlockRule> rules) {
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
                arguments: ConfigureBlockingRulePageArgument(
                  mode: ConfigureBlockingRulePageMode.edit,
                  groupRules: (groupId: groupId, rules: rules),
                ),
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
              await logic.removeLocalBlockRulesByGroupId(groupId);
              logic.getBlockRules();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }
}
