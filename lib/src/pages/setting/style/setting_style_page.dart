import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/locale_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../model/jh_layout.dart';

class SettingStylePage extends StatelessWidget {
  final TagTranslationService tagTranslationService = Get.find();

  SettingStylePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('styleSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildLanguage(),
            _buildBrightness(),
            _buildListMode(),
            if (!StyleSetting.isInWaterFlowListMode) _buildMoveCover2RightSide().fadeIn(),
            _buildTagTranslate(),
            _buildLayout(),
            if (StyleSetting.isInV2Layout) _buildShowBottomNavigation().fadeIn(),
            if (StyleSetting.isInV2Layout) _buildQuickSearch().fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguage() {
    return ListTile(
      title: Text('language'.tr),
      trailing: DropdownButton<Locale>(
        value: StyleSetting.locale.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (Locale? newValue) => StyleSetting.saveLanguage(newValue!),
        items: LocaleText()
            .keys
            .keys
            .map((localeCode) => DropdownMenuItem(
                  child: Text(LocaleConsts.localeCode2Description[localeCode]!),
                  value: localeCode2Locale(localeCode),
                ))
            .toList(),
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
          DropdownMenuItem(child: Text('listWithoutTags'.tr), value: ListMode.listWithoutTags),
          DropdownMenuItem(child: Text('listWithTags'.tr), value: ListMode.listWithTags),
          DropdownMenuItem(child: Text('waterfallFlowWithImageOnly'.tr), value: ListMode.waterfallFlowWithImageOnly),
          DropdownMenuItem(child: Text('waterfallFlowWithImageAndInfo'.tr), value: ListMode.waterfallFlowWithImageAndInfo),
        ],
      ),
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

  Widget _buildTagTranslate() {
    return ListTile(
      title: Text('enableTagZHTranslation'.tr),
      subtitle: tagTranslationService.loadingState.value == LoadingState.success
          ? Text(
              '${'version'.tr}: ${tagTranslationService.timeStamp.value!}',
              style: TextStyle(fontSize: 12, color: Get.theme.colorScheme.outline),
            )
          : tagTranslationService.loadingState.value == LoadingState.loading
              ? Text(
                  '${'downloadTagTranslationHint'.tr}${tagTranslationService.downloadProgress.value}',
                  style: TextStyle(fontSize: 12, color: Get.theme.colorScheme.outline),
                )
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: tagTranslationService.loadingState.value,
            indicatorRadius: 10,
            width: 40,
            idleWidget: IconButton(onPressed: tagTranslationService.refresh, icon: const Icon(Icons.refresh)),
            errorWidgetSameWithIdle: true,
            successWidgetSameWithIdle: true,
          ),
          Switch(
            value: StyleSetting.enableTagZHTranslation.value,
            onChanged: (value) {
              StyleSetting.saveEnableTagZHTranslation(value);
              if (value == true && tagTranslationService.loadingState.value != LoadingState.success) {
                tagTranslationService.refresh();
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildLayout() {
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
                  child: Text(e.name, style: e.isSupported() ? null : TextStyle(color: Get.theme.colorScheme.secondaryContainer)),
                  value: e.mode,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildShowBottomNavigation() {
    return SwitchListTile(
      title: Text('hideBottomBar'.tr),
      value: StyleSetting.hideBottomBar.value,
      onChanged: StyleSetting.saveHideBottomBar,
    );
  }

  Widget _buildQuickSearch() {
    return ListTile(
      title: Text('enableQuickSearchDrawerGesture'.tr),
      trailing: Switch(
        value: StyleSetting.enableQuickSearchDrawerGesture.value,
        onChanged: StyleSetting.saveEnableQuickSearchDrawerGesture,
      ),
    );
  }
}
