import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';

class SettingAccountPage extends StatelessWidget {
  const SettingAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('accountSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            if (!UserSetting.hasLoggedIn())
              ListTile(
                title: Text('login'.tr),
                onTap: () => toNamed(Routes.login),
              ),
            if (UserSetting.hasLoggedIn())
              ListTile(
                title: Text('youHaveLoggedInAs'.tr + UserSetting.userName.value!),
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  color: Colors.red,
                  onPressed: () => Get.dialog(const _LogoutDialog()),
                ),
              ),
            if (UserSetting.hasLoggedIn())
              ListTile(
                title: Text('copyCookies'.tr),
                subtitle: Text('tap2Copy'.tr),
                onTap: () {
                  FlutterClipboard.copy(UserSetting.getCookies())
                      .then((value) => snack('success'.tr, 'hasCopiedToClipboard'.tr));
                },
              ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 4.0),
      title: Center(
        child: Text(
          'logout'.tr + ' ?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              child: Text('cancel'.tr),
              onPressed: () => back(currentRoute: null),
            ),
            TextButton(
              child: Text('OK'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () async {
                EHRequest.logout();
                until(null, (route) => !Get.isDialogOpen!);
              },
            ),
          ],
        )
      ],
    );
  }
}
