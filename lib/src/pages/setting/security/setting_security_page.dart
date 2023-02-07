import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_app_password_setting_dialog.dart';

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
            if (GetPlatform.isMobile) _buildEnableBlurBackgroundApp(),
            _buildEnablePasswordLock(),
            if (SecuritySetting.supportBiometricAuth) _buildEnableBiometricLock(),
            if (SecuritySetting.supportBiometricAuth) _buildEnableBiometricLockOnResume(),
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

  Widget _buildEnablePasswordLock() {
    return ListTile(
      title: Text('enablePasswordLock'.tr),
      trailing: Switch(
        value: SecuritySetting.enablePasswordAuth.value,
        onChanged: (value) async {
          if (value) {
            String? password = await Get.dialog(const EHAppPasswordSettingDialog());

            if (password != null) {
              SecuritySetting.savePassword(password);
              toast('success'.tr);
            } else {
              return;
            }
          }

          SecuritySetting.saveEnablePasswordAuth(value);
        },
      ),
    );
  }

  Widget _buildEnableBiometricLock() {
    return ListTile(
      title: Text('enableBiometricLock'.tr),
      trailing: Switch(value: SecuritySetting.enableBiometricAuth.value, onChanged: SecuritySetting.saveEnableBiometricAuth),
    );
  }

  Widget _buildEnableBiometricLockOnResume() {
    return SwitchListTile(
      title: Text('enableBiometricLockOnResume'.tr),
      subtitle: Text('enableBiometricLockOnResumeHints'.tr),
      value: SecuritySetting.enableAuthOnResume.value,
      onChanged: SecuritySetting.saveEnableAuthOnResume,
    );
  }
}
