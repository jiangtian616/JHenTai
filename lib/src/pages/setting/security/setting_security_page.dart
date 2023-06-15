import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
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
            _buildEnablePasswordAuth(),
            if (SecuritySetting.supportBiometricAuth) _buildEnableBiometricAuth(),
            if (GetPlatform.isMobile) _buildEnableAuthOnResume(),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildEnableBlurBackgroundApp() {
    return ListTile(
      title: Text('enableBlurBackgroundApp'.tr),
      trailing: Switch(value: SecuritySetting.enableBlur.value, onChanged: SecuritySetting.saveEnableBlur),
    );
  }

  Widget _buildEnablePasswordAuth() {
    return ListTile(
      title: Text('enablePasswordAuth'.tr),
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

  Widget _buildEnableBiometricAuth() {
    return ListTile(
      title: Text('enableBiometricAuth'.tr),
      trailing: Switch(value: SecuritySetting.enableBiometricAuth.value, onChanged: SecuritySetting.saveEnableBiometricAuth),
    );
  }

  Widget _buildEnableAuthOnResume() {
    return SwitchListTile(
      title: Text('enableAuthOnResume'.tr),
      subtitle: Text('enableAuthOnResumeHints'.tr),
      value: SecuritySetting.enableAuthOnResume.value,
      onChanged: SecuritySetting.saveEnableAuthOnResume,
    );
  }
}
