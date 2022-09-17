import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
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
    if (!UserSetting.hasLoggedIn()) {
      return const SizedBox();
    }
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('ehSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildSiteSegmentControl(),
            _buildRedirect2EH(),
            _buildSiteSetting(),
            _buildImageLimit(),
            _buildMyTags(),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteSegmentControl() {
    return ListTile(
      title: Text('site'.tr),
      trailing: CupertinoSlidingSegmentedControl<String>(
        groupValue: EHSetting.site.value,
        children: const {
          'EH': Text('E-Hentai'),
          'EX': Text('EXHentai'),
        },
        onValueChanged: (value) => EHSetting.saveSite(value ?? 'EH'),
      ),
    );
  }

  Widget _buildRedirect2EH() {
    if (EHSetting.site.value == 'EH') {
      return const SizedBox();
    }

    return FadeIn(
      child: ListTile(
        title: Text('redirect2Eh'.tr),
        trailing: Switch(value: EHSetting.redirect2Eh.value, onChanged: EHSetting.saveRedirect2Eh),
      ),
    );
  }

  Widget _buildSiteSetting() {
    return ListTile(
      title: Text('siteSetting'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        if (GetPlatform.isDesktop) {
          launchUrlString(EHConsts.EUconfig);
          return;
        }

        List<Cookie> cookies = await Get.find<EHCookieManager>().getCookie(Uri.parse(EHConsts.EIndex));
        await toRoute(
          Routes.webview,
          arguments: {
            'title': 'siteSetting'.tr,
            'url': EHConsts.EUconfig,
            'cookies': CookieUtil.parse2String(cookies),
          },
        );

        SiteSetting.refresh();
      },
    );
  }

  Widget _buildImageLimit() {
    return ListTile(
      title: Text('imageLimits'.tr),
      onTap: EHSetting.refresh,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: EHSetting.refreshState.value,
            indicatorRadius: 10,
            idleWidget: const SizedBox(),
            errorWidgetSameWithIdle: true,
          ).marginOnly(right: 12),
          Text('${EHSetting.currentConsumption} / ${EHSetting.totalLimit}').marginOnly(right: 4),
          const Icon(Icons.keyboard_arrow_right),
        ],
      ),
    );
  }

  Widget _buildMyTags() {
    return ListTile(
      title: Text('myTags'.tr),
      subtitle: Text('myTagsHint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.tagSets),
    );
  }
}
