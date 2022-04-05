import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';

import '../../../setting/eh_setting.dart';
import '../../../utils/route_util.dart';

class SettingEHPage extends StatelessWidget {
  const SettingEHPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('ehSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            if (!UserSetting.hasLoggedIn())
              ListTile(
                title: Text('pleaseLogInToOperate'.tr),
              ),
            if (UserSetting.hasLoggedIn())
              ListTile(
                title: Text('site'.tr),
                trailing: CupertinoSlidingSegmentedControl<String>(
                  groupValue: EHSetting.site.value,
                  children: const {
                    'EH': Text('E-Hentai'),
                    'EX': Text('EXHentai'),
                  },
                  onValueChanged: (value) {
                    EHSetting.saveSite(value!);
                  },
                ),
              ),
            if (UserSetting.hasLoggedIn())
              ListTile(
                title: Text('siteSetting'.tr),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _gotoSiteSettingPage,
              ),
            if (UserSetting.hasLoggedIn() && EHSetting.site.value == 'EX')
              ListTile(
                title: Text('redirect2EH'.tr),
                subtitle: Text('redirect2Hints'.tr),
                trailing: Switch(
                  value: EHSetting.redirect2EH.value,
                  onChanged: EHSetting.saveRedirect2EH,
                ),
              ),
          ],
        );
      }).paddingSymmetric(vertical: 16),
    );
  }

  Future<void> _gotoSiteSettingPage() async {
    List<Cookie> cookies = await EHRequest.getCookie(Uri.parse(EHConsts.EIndex));
    await toNamed(
      Routes.webview,
      arguments: EHConsts.EUconfig,
      parameters: {'cookies': CookieUtil.parse2String(cookies)},
    );
    SiteSetting.refresh();
  }
}
