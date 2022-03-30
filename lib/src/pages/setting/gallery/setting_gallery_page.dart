import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/gallery_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class SettingGalleryPage extends StatelessWidget {
  final TagTranslationService tagTranslationService = Get.find();

  SettingGalleryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('gallerySetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('enableDarkTheme'.tr),
              trailing: Switch(
                value: GallerySetting.enableDarkTheme.value,
                onChanged: GallerySetting.saveEnableDarkTheme,
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
                        GallerySetting.enableTagZHTranslation.isTrue)
                      const CupertinoActivityIndicator().marginOnly(right: 8),
                    Switch(
                      value: GallerySetting.enableTagZHTranslation.value,
                      onChanged: (value) {
                        GallerySetting.saveEnableTagZHTranslation(value);
                        if (value == true) {
                          Get.find<TagTranslationService>().updateDatabase();
                        }
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
