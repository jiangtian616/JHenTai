import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../../setting/user_setting.dart';
import '../../utils/route_util.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('setting'.tr),
          elevation: 1,
        ),
        body: Obx(() {
          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text('account'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'account'),
              ),
              if (UserSetting.hasLoggedIn())
                ListTile(
                  leading: const Icon(Icons.mood),
                  title: Text('EH'.tr),
                  onTap: () => toNamed(Routes.settingPrefix + 'EH'),
                ),
              ListTile(
                leading: const Icon(Icons.style),
                title: Text('style'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'style'),
              ),
              ListTile(
                leading: const Icon(Icons.local_library),
                title: Text('read'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'read'),
              ),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: Text('network'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'network'),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text('download'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'download'),
              ),
              if (StyleSetting.actualLayoutMode.value == LayoutMode.desktop)
                ListTile(
                  leading: const Icon(Icons.mouse),
                  title: Text('mouseWheel'.tr),
                  onTap: () => toNamed(Routes.settingPrefix + 'mouse_wheel'),
                ),
              ListTile(
                leading: const Icon(Icons.settings_suggest),
                title: Text('advanced'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'advanced'),
              ),
              if (!GetPlatform.isDesktop)
                ListTile(
                  leading: const Icon(Icons.security),
                  title: Text('security'.tr),
                  onTap: () => toNamed(Routes.settingPrefix + 'security'),
                ),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text('about'.tr),
                onTap: () => toNamed(Routes.settingPrefix + 'about'),
              ),
            ],
          );
        }).paddingSymmetric(vertical: 16),
      ),
    );
  }
}
