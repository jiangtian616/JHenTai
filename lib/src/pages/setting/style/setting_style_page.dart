import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
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
      appBar: AppBar(
        centerTitle: true,
        title: Text('styleSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('language'.tr),
              trailing: DropdownButton<Locale>(
                value: StyleSetting.locale.value,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (Locale? newValue) {
                  StyleSetting.saveLanguage(newValue!);
                },
                items: LocaleText()
                    .keys
                    .keys
                    .map((localeCode) => DropdownMenuItem(
                          child: Text(LocaleConsts.localeCode2Description[localeCode]!),
                          value: localeCode2Locale(localeCode),
                        ))
                    .toList(),
              ),
            ),
            ListTile(
              title: Text('themeMode'.tr),
              trailing: DropdownButton<ThemeMode>(
                value: StyleSetting.themeMode.value,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (ThemeMode? newValue) {
                  StyleSetting.saveThemeMode(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('light'.tr),
                    value: ThemeMode.light,
                  ),
                  DropdownMenuItem(
                    child: Text('dark'.tr),
                    value: ThemeMode.dark,
                  ),
                  DropdownMenuItem(
                    child: Text('followSystem'.tr),
                    value: ThemeMode.system,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('listStyle'.tr),
              trailing: DropdownButton<ListMode>(
                value: StyleSetting.listMode.value,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (ListMode? newValue) {
                  StyleSetting.saveListMode(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('flat'.tr),
                    value: ListMode.flat,
                  ),
                  DropdownMenuItem(
                    child: Text('listWithoutTags'.tr),
                    value: ListMode.listWithoutTags,
                  ),
                  DropdownMenuItem(
                    child: Text('listWithTags'.tr),
                    value: ListMode.listWithTags,
                  ),
                  DropdownMenuItem(
                    child: Text('waterfallFlowWithImageOnly'.tr),
                    value: ListMode.waterfallFlowWithImageOnly,
                  ),
                  DropdownMenuItem(
                    child: Text('waterfallFlowWithImageAndInfo'.tr),
                    value: ListMode.waterfallFlowWithImageAndInfo,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('coverStyle'.tr),
              trailing: DropdownButton<CoverMode>(
                value: StyleSetting.coverMode.value,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (CoverMode? newValue) {
                  StyleSetting.saveCoverMode(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('cover'.tr),
                    value: CoverMode.cover,
                  ),
                  DropdownMenuItem(
                    child: Text('adaptive'.tr),
                    value: CoverMode.contain,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('enableTagZHTranslation'.tr),
              subtitle: tagTranslationService.loadingState.value == LoadingState.success
                  ? Text(
                      '${'version'.tr}: ${tagTranslationService.timeStamp.value!}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    )
                  : tagTranslationService.loadingState.value == LoadingState.loading
                      ? Text(
                          '${'downloadTagTranslationHint'.tr}${tagTranslationService.downloadProgress.value}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        )
                      : null,
              trailing: SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LoadingStateIndicator(
                      loadingState: tagTranslationService.loadingState.value,
                      width: 40,
                      idleWidget: IconButton(
                        onPressed: tagTranslationService.refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      errorWidgetSameWithIdle: true,
                      successWidgetSameWithIdle: true,
                    ),
                    Switch(
                      value: StyleSetting.enableTagZHTranslation.value,
                      onChanged: (value) {
                        StyleSetting.saveEnableTagZHTranslation(value);
                        if (value == true && tagTranslationService.loadingState.value != LoadingState.success) {
                          Get.find<TagTranslationService>().refresh();
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
            ListTile(
              title: Text('layoutMode'.tr),
              subtitle: Text(JHLayout.allLayouts.firstWhere((e) => e.mode == StyleSetting.layout.value).desc),
              trailing: DropdownButton<LayoutMode>(
                value: StyleSetting.actualLayout,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (LayoutMode? newValue) => StyleSetting.saveLayoutMode(newValue!),
                items: JHLayout.allLayouts.where((layout) => layout.isSupported()).map((e) => DropdownMenuItem(child: Text(e.name), value: e.mode)).toList(),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
