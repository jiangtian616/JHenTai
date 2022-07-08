import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../setting/eh_setting.dart';
import '../../../utils/route_util.dart';

class SettingEHPage extends StatelessWidget {
  SettingEHPage({Key? key}) : super(key: key) {
    EHSetting.refresh();
  }

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
            ListTile(
              title: Text('siteSetting'.tr),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _gotoSiteSettingPage,
            ),
            ListTile(
              title: Text('imageLimits'.tr),
              trailing: SizedBox(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LoadingStateIndicator(
                      loadingState: EHSetting.refreshState.value,
                      width: 40,
                      indicatorRadius: 10,
                      idleWidget: const IconButton(
                        onPressed: EHSetting.refresh,
                        icon: Icon(Icons.refresh, size: 20),
                      ),
                      errorWidgetSameWithIdle: true,
                    ),
                    Text('${EHSetting.currentConsumption} / ${EHSetting.totalLimit}'),
                  ],
                ),
              ),
            ),
            ListTile(
              title: Text('myTags'.tr),
              subtitle: Text('myTagsHint'.tr),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16).marginOnly(right: 4),
              onTap: () => toNamed(Routes.tagSets),
            ),
          ],
        );
      }).paddingSymmetric(vertical: 16),
    );
  }

  Future<void> _gotoSiteSettingPage() async {
    if (GetPlatform.isDesktop) {
      launchUrlString(EHConsts.EUconfig);
      return;
    }

    List<Cookie> cookies = await Get.find<EHCookieManager>().getCookie(Uri.parse(EHConsts.EIndex));
    await toNamed(
      Routes.webview,
      arguments: {
        'url': EHConsts.EUconfig,
        'cookies': CookieUtil.parse2String(cookies),
      },
    );
    SiteSetting.refresh();
  }
}
