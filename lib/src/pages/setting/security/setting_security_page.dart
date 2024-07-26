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
            if (securitySetting.supportBiometricAuth) _buildEnableBiometricAuth(),
            if (GetPlatform.isMobile) _buildEnableAuthOnResume(),
            if (GetPlatform.isAndroid) _buildHideImagesInAlbum(),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildEnableBlurBackgroundApp() {
    return SwitchListTile(
      title: Text('enableBlurBackgroundApp'.tr),
      value: securitySetting.enableBlur.value,
      onChanged: securitySetting.saveEnableBlur,
    );
  }

  Widget _buildEnablePasswordAuth() {
    return SwitchListTile(
      title: Text('enablePasswordAuth'.tr),
      value: securitySetting.enablePasswordAuth.value,
      onChanged: (value) async {
        if (value) {
          String? password = await Get.dialog(const EHAppPasswordSettingDialog());

          if (password != null) {
            securitySetting.savePassword(password);
            toast('success'.tr);
          } else {
            return;
          }
        }

        securitySetting.saveEnablePasswordAuth(value);
      },
    );
  }

  Widget _buildEnableBiometricAuth() {
    return SwitchListTile(
      title: Text('enableBiometricAuth'.tr),
      value: securitySetting.enableBiometricAuth.value,
      onChanged: securitySetting.saveEnableBiometricAuth,
    );
  }

  Widget _buildEnableAuthOnResume() {
    return SwitchListTile(
      title: Text('enableAuthOnResume'.tr),
      subtitle: Text('enableAuthOnResumeHints'.tr),
      value: securitySetting.enableAuthOnResume.value,
      onChanged: securitySetting.saveEnableAuthOnResume,
    );
  }

  Widget _buildHideImagesInAlbum() {
    return SwitchListTile(
      title: Text('hideImagesInAlbum'.tr),
      value: securitySetting.hideImagesInAlbum.value,
      onChanged: securitySetting.saveHideImagesInAlbum,
    );
  }
}
