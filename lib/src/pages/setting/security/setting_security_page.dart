import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/security_setting.dart';

class SettingSecurityPage extends StatelessWidget {
  const SettingSecurityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('securitySetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            if (SecuritySetting.supportFingerPrintLock)
              ListTile(
                title: Text('enableFingerPrintLock'.tr),
                trailing: Switch(
                  value: SecuritySetting.enableFingerPrintLock.value,
                  onChanged: SecuritySetting.saveEnableFingerPrintLock,
                ),
              ),
            ListTile(
              title: Text('enableBlurBackgroundApp'.tr),
              trailing: Switch(
                value: SecuritySetting.enableBlur.value,
                onChanged: SecuritySetting.saveEnableBlur,
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
