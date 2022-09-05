import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../network/eh_cookie_manager.dart';
import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../widget/log_out_dialog.dart';

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
              _buildLogout(),
              _buildCopyCookie(),
            ],
          ],
        ),
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

  Widget _buildLogout() {
    return ListTile(
      title: Text('youHaveLoggedInAs'.tr + UserSetting.userName.value!),
      onTap: () => Get.dialog(const LogoutDialog()),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        color: Get.theme.colorScheme.error,
        onPressed: () => Get.dialog(const LogoutDialog()),
      ),
    );
  }

  Widget _buildCopyCookie() {
    return ListTile(
      title: Text('copyCookies'.tr),
      subtitle: Text('tap2Copy'.tr),
      onTap: () async {
        List<Cookie> cookies = await Get.find<EHCookieManager>().getCookie(Uri.parse(EHConsts.EIndex));
        await FlutterClipboard.copy(CookieUtil.parse2String(cookies));
        toast('hasCopiedToClipboard'.tr);
      },
    );
  }
}
