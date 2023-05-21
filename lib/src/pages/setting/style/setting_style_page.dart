import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../../../model/jh_layout.dart';
import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';

class SettingStylePage extends StatelessWidget {
  const SettingStylePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('styleSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildBrightness(),
            _buildThemeColor(),
            _buildListMode(),
            if (StyleSetting.isInWaterFlowListMode) _buildCrossAxisCountInWaterFallFlow().fadeIn(),
            _buildPageListMode(),
            _buildCrossAxisCountInGridDownloadPageForGroup(),
            _buildCrossAxisCountInGridDownloadPageForGallery(),
            if (!StyleSetting.isInWaterFlowListMode) _buildMoveCover2RightSide().fadeIn(),
            _buildLayout(context),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildBrightness() {
    return ListTile(
      title: Text('themeMode'.tr),
      trailing: DropdownButton<ThemeMode>(
        value: StyleSetting.themeMode.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (ThemeMode? newValue) => StyleSetting.saveThemeMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('light'.tr), value: ThemeMode.light),
          DropdownMenuItem(child: Text('dark'.tr), value: ThemeMode.dark),
          DropdownMenuItem(child: Text('followSystem'.tr), value: ThemeMode.system),
        ],
      ),
    );
  }

  Widget _buildThemeColor() {
    return ListTile(
      title: Text('themeColor'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.themeColor),
    );
  }

  Widget _buildListMode() {
    return ListTile(
      title: Text('listStyle'.tr),
      trailing: DropdownButton<ListMode>(
        value: StyleSetting.listMode.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (ListMode? newValue) => StyleSetting.saveListMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('flat'.tr), value: ListMode.flat),
          DropdownMenuItem(child: Text('flatWithoutTags'.tr), value: ListMode.flatWithoutTags),
          DropdownMenuItem(child: Text('listWithTags'.tr), value: ListMode.listWithTags),
          DropdownMenuItem(child: Text('listWithoutTags'.tr), value: ListMode.listWithoutTags),
          DropdownMenuItem(child: Text('waterfallFlowSmall'.tr), value: ListMode.waterfallFlowSmall),
          DropdownMenuItem(child: Text('waterfallFlowMedium'.tr), value: ListMode.waterfallFlowMedium),
          DropdownMenuItem(child: Text('waterfallFlowBig'.tr), value: ListMode.waterfallFlowBig),
        ],
      ),
    );
  }

  Widget _buildCrossAxisCountInWaterFallFlow() {
    return ListTile(
      title: Text('crossAxisCountInWaterFallFlow'.tr),
      trailing: DropdownButton<int?>(
        value: StyleSetting.crossAxisCountInWaterFallFlow.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: StyleSetting.saveCrossAxisCountInWaterFallFlow,
        items: [
          DropdownMenuItem(child: Text('auto'.tr), value: null),
          DropdownMenuItem(child: Text('2'.tr), value: 2),
          DropdownMenuItem(child: Text('3'.tr), value: 3),
          DropdownMenuItem(child: Text('4'.tr), value: 4),
          DropdownMenuItem(child: Text('5'.tr), value: 5),
          DropdownMenuItem(child: Text('6'.tr), value: 6),
        ],
      ),
    );
  }

  Widget _buildCrossAxisCountInGridDownloadPageForGroup() {
    return ListTile(
      title: Text('crossAxisCountInGridDownloadPageForGroup'.tr),
      trailing: DropdownButton<int?>(
        value: StyleSetting.crossAxisCountInGridDownloadPageForGroup.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: StyleSetting.saveCrossAxisCountInGridDownloadPageForGroup,
        items: [
          DropdownMenuItem(child: Text('auto'.tr), value: null),
          DropdownMenuItem(child: Text('2'.tr), value: 2),
          DropdownMenuItem(child: Text('3'.tr), value: 3),
          DropdownMenuItem(child: Text('4'.tr), value: 4),
          DropdownMenuItem(child: Text('5'.tr), value: 5),
          DropdownMenuItem(child: Text('6'.tr), value: 6),
        ],
      ),
    );
  }

  Widget _buildCrossAxisCountInGridDownloadPageForGallery() {
    return ListTile(
      title: Text('crossAxisCountInGridDownloadPageForGallery'.tr),
      trailing: DropdownButton<int?>(
        value: StyleSetting.crossAxisCountInGridDownloadPageForGallery.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: StyleSetting.crossAxisCountInGridDownloadPageForGallery,
        items: [
          DropdownMenuItem(child: Text('auto'.tr), value: null),
          DropdownMenuItem(child: Text('2'.tr), value: 2),
          DropdownMenuItem(child: Text('3'.tr), value: 3),
          DropdownMenuItem(child: Text('4'.tr), value: 4),
          DropdownMenuItem(child: Text('5'.tr), value: 5),
          DropdownMenuItem(child: Text('6'.tr), value: 6),
        ],
      ),
    );
  }

  Widget _buildPageListMode() {
    return ListTile(
      title: Text('pageListStyle'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.pageListStyle),
    );
  }

  Widget _buildMoveCover2RightSide() {
    return SwitchListTile(
      title: Text('moveCover2RightSide'.tr),
      subtitle: Text('needRestart'.tr),
      value: StyleSetting.moveCover2RightSide.value,
      onChanged: StyleSetting.saveMoveCover2RightSide,
    );
  }

  Widget _buildLayout(BuildContext context) {
    return ListTile(
      title: Text('layoutMode'.tr),
      subtitle: Text(JHLayout.allLayouts.firstWhere((e) => e.mode == StyleSetting.layout.value).desc),
      trailing: DropdownButton<LayoutMode>(
        value: StyleSetting.actualLayout,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (LayoutMode? newValue) => StyleSetting.saveLayoutMode(newValue!),
        items: JHLayout.allLayouts
            .map((e) => DropdownMenuItem(
                  enabled: e.isSupported(),
                  child: Text(e.name, style: e.isSupported() ? null : TextStyle(color: UIConfig.settingPageLayoutSelectorUnSupportColor(context))),
                  value: e.mode,
                ))
            .toList(),
      ),
    );
  }
}
