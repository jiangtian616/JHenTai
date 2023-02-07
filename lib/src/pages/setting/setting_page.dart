import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../../model/jh_layout.dart';
import '../../setting/user_setting.dart';
import '../../utils/route_util.dart';
import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';

class SettingPage extends StatelessWidget {
  final bool showMenuButton;

  const SettingPage({Key? key, this.showMenuButton = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('setting'.tr),
        leading: showMenuButton
            ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
            : null,
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text('account'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'account'),
            ),
            if (UserSetting.hasLoggedIn())
              ListTile(
                leading: const Icon(Icons.mood),
                title: Text('EH'.tr),
                onTap: () => toRoute(Routes.settingPrefix + 'EH'),
              ),
            ListTile(
              leading: const Icon(Icons.style),
              title: Text('style'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'style'),
            ),
            ListTile(
              leading: const Icon(Icons.local_library),
              title: Text('read'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'read'),
            ),
            ListTile(
              leading: const Icon(Icons.stars),
              title: Text('preference'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'preference'),
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: Text('network'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'network'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text('download'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'download'),
            ),
            if (StyleSetting.actualLayout == LayoutMode.desktop && GetPlatform.isDesktop)
              ListTile(
                leading: const Icon(Icons.mouse),
                title: Text('mouseWheel'.tr),
                onTap: () => toRoute(Routes.settingPrefix + 'mouse_wheel'),
              ),
            ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: Text('advanced'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'advanced'),
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text('security'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'security'),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text('about'.tr),
              onTap: () => toRoute(Routes.settingPrefix + 'about'),
            ),
          ],
        ),
      ),
    );
  }
}
