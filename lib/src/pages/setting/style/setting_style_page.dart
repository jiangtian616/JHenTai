import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/locale_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../utils/size_util.dart';

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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('enableTagZHTranslation'.tr),
                  if (tagTranslationService.loadingState.value == LoadingState.success)
                    Text(
                      '${'version'.tr}: ${tagTranslationService.timeStamp.value!}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  if (tagTranslationService.loadingState.value == LoadingState.loading)
                    Text(
                      'downloadTagTranslationHint'.tr + tagTranslationService.downloadProgress.value,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
              trailing: SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (tagTranslationService.loadingState.value == LoadingState.loading &&
                        StyleSetting.enableTagZHTranslation.isTrue)
                      const CupertinoActivityIndicator().marginOnly(right: 8),
                    Switch(
                      value: StyleSetting.enableTagZHTranslation.value,
                      onChanged: (value) {
                        StyleSetting.saveEnableTagZHTranslation(value);
                        if (value == true) {
                          Get.find<TagTranslationService>().updateDatabase();
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
            if (fullScreenWidth >= 600)
              ListTile(
                title: Text('enableTabletLayout'.tr),
                trailing: Switch(
                  value: StyleSetting.enableTabletLayout.value,
                  onChanged: StyleSetting.saveEnableTabletLayout,
                ),
              ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
