import 'dart:developer';

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
              trailing: CupertinoSwitch(
                value: AdvancedSetting.enableDomainFronting.value,
                onChanged: (value) => AdvancedSetting.saveEnableDomainFronting(value),
              ),
            ),
            ListTile(
              title: Text('enableLogging'.tr),
              trailing: CupertinoSwitch(
                value: AdvancedSetting.enableLogging.value,
                onChanged: (value) => AdvancedSetting.saveEnableLogging(value),
              ),
            ),
            ListTile(
              title: Text('openLog'.tr),
              onTap: () => Get.toNamed(Routes.logList),
            ),
            ListTile(
              title: Text('clearLogs'.tr),
              trailing: TextButton(
                onPressed: () {
                  Log.clear();
                  setState(() {});
                },
                child: Text(Log.getSizeInKB()),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
