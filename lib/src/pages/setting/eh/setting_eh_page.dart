import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../exception/eh_exception.dart';
import '../../../setting/eh_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';

class SettingEHPage extends StatefulWidget {
  const SettingEHPage({Key? key}) : super(key: key);

  @override
  State<SettingEHPage> createState() => _SettingEHPageState();
}

class _SettingEHPageState extends State<SettingEHPage> {
  LoadingState assetsLoadingState = LoadingState.idle;
  LoadingState resetLimitLoadingState = LoadingState.idle;
  String credit = '-1';
  String gp = '-1';

  @override
  void initState() {
    EHSetting.refresh();
    getAssets();
    super.initState();
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
            _buildUseSeparateProfile(),
            _buildSiteSetting(),
            _buildImageLimit(),
            _buildAssets(),
            _buildMyTags(),
          ],
        ).withListTileTheme(context),
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

  Widget _buildUseSeparateProfile() {
    return ListTile(
      title: Text('useSeparateProfile'.tr),
      trailing: Switch(value: SiteSetting.useSeparateProfile.value, onChanged: SiteSetting.saveUseSeparateProfile),
    );
  }

  Widget _buildSiteSetting() {
    return ListTile(
      title: Text('siteSetting'.tr),
      subtitle: Text('editProfileHint'.tr),
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
    return GestureDetector(
      onLongPress: resetLimit,
      child: ListTile(
        title: Text('imageLimits'.tr),
        subtitle: Text('${'resetCost'.tr} ${EHSetting.resetCost} GP'),
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
      ),
    );
  }

  Widget _buildAssets() {
    return ListTile(
      title: Text('assets'.tr),
      subtitle: Text('GP: $gp    Credits: $credit'),
      onTap: getAssets,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: assetsLoadingState,
            indicatorRadius: 10,
            idleWidget: const SizedBox(),
            errorWidgetSameWithIdle: true,
          ),
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

  Future<void> getAssets() async {
    if (assetsLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() {
      assetsLoadingState = LoadingState.loading;
    });

    Map<String, String> assets;
    try {
      assets = await EHRequest.requestExchangePage(parser: EHSpiderParser.exchangePage2Assets);
    } on DioError catch (e) {
      Log.error('Get assets failed', e.message);
      snack('Get assets failed'.tr, e.message, longDuration: true);
      setStateSafely(() {
        assetsLoadingState = LoadingState.error;
      });
      return;
    } on EHException catch (e) {
      Log.error('Get assets failed', e.message);
      snack('Get assets failed'.tr, e.message, longDuration: true);
      setStateSafely(() {
        assetsLoadingState = LoadingState.error;
      });
      return;
    }

    setStateSafely(() {
      gp = assets['gp']!;
      credit = assets['credit']!;
      assetsLoadingState = LoadingState.success;
    });
  }

  Future<void> resetLimit() async {
    if (resetLimitLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() {
      resetLimitLoadingState = LoadingState.loading;
    });

    try {
      await EHRequest.requestResetImageLimit();
    } on DioError catch (e) {
      Log.error('Reset limit failed', e.message);
      snack('Reset limit failed'.tr, e.message, longDuration: true);
      setStateSafely(() {
        resetLimitLoadingState = LoadingState.error;
      });
      return;
    } on EHException catch (e) {
      Log.error('Reset limit failed', e.message);
      snack('Reset limit failed'.tr, e.message, longDuration: true);
      setStateSafely(() {
        resetLimitLoadingState = LoadingState.error;
      });
      return;
    }

    setStateSafely(() {
      resetLimitLoadingState = LoadingState.success;
    });

    EHSetting.refresh();
    getAssets();
  }
}
