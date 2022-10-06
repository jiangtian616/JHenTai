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
            _buildEnableBlurBackgroundApp(),
            if (SecuritySetting.supportBiometricLock) _buildEnableBiometricLock(),
            if (SecuritySetting.supportBiometricLock) _buildEnableBiometricLockOnResume(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableBlurBackgroundApp() {
    return ListTile(
      title: Text('enableBlurBackgroundApp'.tr),
      trailing: Switch(value: SecuritySetting.enableBlur.value, onChanged: SecuritySetting.saveEnableBlur),
    );
  }

  Widget _buildEnableBiometricLock() {
    return ListTile(
      title: Text('enableBiometricLock'.tr),
      trailing: Switch(value: SecuritySetting.enableBiometricLock.value, onChanged: SecuritySetting.saveEnableBiometricLock),
    );
  }

  Widget _buildEnableBiometricLockOnResume() {
    return SwitchListTile(
      title: Text('enableBiometricLockOnResume'.tr),
      subtitle: Text('enableBiometricLockOnResumeHints'.tr),
      value: SecuritySetting.enableBiometricLockOnResume.value,
      onChanged: SecuritySetting.saveEnableBiometricLockOnResume,
    );
  }
}
