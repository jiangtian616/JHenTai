import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/security_setting.dart';

class SettingSecurityPage extends StatelessWidget {
  const SettingSecurityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('securitySetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            if (SecuritySetting.supportFingerPrintLock) _buildEnableFingerPrintLock(),
            if (SecuritySetting.supportFingerPrintLock) _buildEnableFingerPrintLockOnResume(),
            _buildEnableBlurBackgroundApp(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableFingerPrintLock() {
    return ListTile(
      title: Text('enableFingerPrintLock'.tr),
      trailing: Switch(value: SecuritySetting.enableFingerPrintLock.value, onChanged: SecuritySetting.saveEnableFingerPrintLock),
    );
  }

  Widget _buildEnableFingerPrintLockOnResume() {
    return SwitchListTile(
      title: Text('enableFingerPrintLockOnResume'.tr),
      subtitle: Text('enableFingerPrintLockOnResumeHints'.tr),
      value: SecuritySetting.enableFingerPrintLockOnResume.value,
      onChanged: SecuritySetting.saveEnableFingerPrintLockOnResume,
    );
  }

  Widget _buildEnableBlurBackgroundApp() {
    return ListTile(
      title: Text('enableBlurBackgroundApp'.tr),
      trailing: Switch(value: SecuritySetting.enableBlur.value, onChanged: SecuritySetting.saveEnableBlur),
    );
  }
}
