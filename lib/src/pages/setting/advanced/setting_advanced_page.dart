import 'dart:io' as io;
import 'dart:math';

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
              trailing: Text(
                Log.getSizeInKB(),
                style: TextStyle(color: Get.theme.primaryColor, fontWeight: FontWeight.w500),
              ).marginOnly(right: 8),
              onTap: () {
                Log.clear();
                setState(() {});
              },
            ),
            ListTile(
              title: Text('clearImagesCache'.tr),
              trailing: Text(
                _getImagesCacheSizeInKB(),
                style: TextStyle(color: Get.theme.primaryColor, fontWeight: FontWeight.w500),
              ).marginOnly(right: 8),
              onTap: () async {
                await clearDiskCachedImages();
                setState(() {});
              },
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }

  String _getImagesCacheSizeInKB() {
    io.Directory cacheImagesDirectory = io.Directory(join(PathSetting.tempDir.path, cacheImageFolderName));
    return max((cacheImagesDirectory.statSync().size / 1024), 0).toStringAsFixed(2) + 'KB';
  }
}
