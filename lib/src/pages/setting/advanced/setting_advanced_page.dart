import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/utils/log.dart';

import '../../../routes/routes.dart';

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
            ),
            ListTile(
              title: Text('openLog'.tr),
              trailing: const Icon(Icons.arrow_forward_ios, size: 20).marginOnly(right: 4),
              onTap: () => Get.toNamed(Routes.logList),
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
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
