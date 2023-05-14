import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import '../../../network/eh_cookie_manager.dart';
import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../utils/toast_util.dart';
import '../../../widget/eh_log_out_dialog.dart';

class SettingAccountPage extends StatelessWidget {
  const SettingAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('accountSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            if (!UserSetting.hasLoggedIn()) _buildLogin(),
            if (UserSetting.hasLoggedIn()) ...[
              _buildLogout(context).marginOnly(bottom: 12),
              _buildCookiePage(),
            ],
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildLogin() {
    return ListTile(
      title: Text('login'.tr),
      trailing: IconButton(onPressed: () => toRoute(Routes.login), icon: const Icon(Icons.keyboard_arrow_right)),
      onTap: () => toRoute(Routes.login),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return ListTile(
      title: Text('${'youHaveLoggedInAs'.tr}${UserSetting.nickName.value ?? UserSetting.userName.value!}'),
      onTap: () => Get.dialog(const LogoutDialog()),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        color: UIConfig.alertColor(context),
        onPressed: () => Get.dialog(const LogoutDialog()),
      ),
    );
  }

  Widget _buildCookiePage() {
    return ListTile(
      title: Text('showCookie'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.cookie),
      onLongPress: _copyCookies,
    );
  }

  Future<void> _copyCookies() async {
    await FlutterClipboard.copy(EHCookieManager.userCookies);
    toast('hasCopiedToClipboard'.tr);
  }
}
