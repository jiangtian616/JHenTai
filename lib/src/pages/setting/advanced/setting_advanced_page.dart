import 'dart:io' as io;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';

class SettingAdvancedPage extends StatefulWidget {
  const SettingAdvancedPage({Key? key}) : super(key: key);

  @override
  _SettingAdvancedPageState createState() => _SettingAdvancedPageState();
}

class _SettingAdvancedPageState extends State<SettingAdvancedPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('advancedSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('enableDomainFronting'.tr),
              trailing: Switch(
                value: AdvancedSetting.enableDomainFronting.value,
                onChanged: (value) => AdvancedSetting.saveEnableDomainFronting(value),
              ),
            ),
            ListTile(
              title: Text('pageCacheMaxAge'.tr),
              subtitle: Text('pageCacheMaxAgeHint'.tr),
              trailing: DropdownButton<Duration>(
                value: AdvancedSetting.pageCacheMaxAge.value,
                elevation: 4,
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (Duration? newValue) {
                  AdvancedSetting.savePageCacheMaxAge(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('oneMinute'.tr),
                    value: const Duration(minutes: 1),
                  ),
                  DropdownMenuItem(
                    child: Text('tenMinute'.tr),
                    value: const Duration(minutes: 10),
                  ),
                  DropdownMenuItem(
                    child: Text('oneHour'.tr),
                    value: const Duration(hours: 1),
                  ),
                  DropdownMenuItem(
                    child: Text('oneDay'.tr),
                    value: const Duration(days: 1),
                  ),
                  DropdownMenuItem(
                    child: Text('threeDay'.tr),
                    value: const Duration(days: 3),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('enableLogging'.tr),
              trailing: Switch(
                value: AdvancedSetting.enableLogging.value,
                onChanged: (value) => AdvancedSetting.saveEnableLogging(value),
              ),
              subtitle: Text('needRestart'.tr),
            ),
            ListTile(
              title: Text('openLog'.tr),
              trailing: const Icon(Icons.arrow_forward_ios, size: 20).marginOnly(right: 4),
              onTap: () => toNamed(Routes.logList),
            ),
            ListTile(
              title: Text('clearLogs'.tr),
              subtitle: Text('longPress2Clear'.tr),
              trailing: Text(
                Log.getSize(),
                style: TextStyle(color: Get.theme.primaryColor, fontWeight: FontWeight.w500),
              ).marginOnly(right: 8),
              onLongPress: () {
                Log.clear();
                setState(() {});
              },
            ),
            ListTile(
              title: Text('clearImagesCache'.tr),
              subtitle: Text('longPress2Clear'.tr),
              trailing: Text(
                _getImagesCacheSize(),
                style: TextStyle(color: Get.theme.primaryColor, fontWeight: FontWeight.w500),
              ).marginOnly(right: 8),
              onLongPress: () async {
                await clearDiskCachedImages();
                setState(() {});
              },
            ),
            ListTile(
              title: Text('checkUpdateAfterLaunchingApp'.tr),
              trailing: Switch(
                value: AdvancedSetting.enableCheckUpdate.value,
                onChanged: (value) => AdvancedSetting.saveEnableCheckUpdate(value),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }

  String _getImagesCacheSize() {
    io.Directory cacheImagesDirectory = io.Directory(join(PathSetting.tempDir.path, cacheImageFolderName));
    if (!cacheImagesDirectory.existsSync()) {
      return '0KB';
    }

    int totalBytes = cacheImagesDirectory
        .listSync()
        .fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());

    return (totalBytes / 1024 / 1024).toStringAsFixed(2) + 'MB';
  }
}
