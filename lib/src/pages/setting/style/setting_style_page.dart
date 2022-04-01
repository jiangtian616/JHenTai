import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

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
              title: Text('themeMode'.tr),
              trailing: DropdownButton<EHThemeMode>(
                value: StyleSetting.themeMode.value,
                elevation: 4,
                onChanged: (EHThemeMode? newValue) {
                  StyleSetting.saveThemeMode(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('light'.tr),
                    value: EHThemeMode.light,
                  ),
                  DropdownMenuItem(
                    child: Text('dark'.tr),
                    value: EHThemeMode.dark,
                  ),
                  DropdownMenuItem(
                    child: Text('followSystem'.tr),
                    value: EHThemeMode.system,
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
