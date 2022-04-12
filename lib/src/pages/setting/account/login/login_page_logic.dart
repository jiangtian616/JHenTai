import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../network/eh_cookie_manager.dart';
import '../../../../utils/cookie_util.dart';
import '../../../../utils/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
import 'login_page_state.dart';

class LoginPageLogic extends GetxController {
  final LoginPageState state = LoginPageState();
  final EHCookieManager cookieManager = Get.find<EHCookieManager>();

  void changeLoginType() {
    state.loginType = (state.loginType == LoginType.cookie ? LoginType.password : LoginType.cookie);
    update();
  }

  Future<void> handleLogin() async {
    if (state.loginState == LoadingState.loading) {
      return;
    }

    if (state.loginType == LoginType.password) {
      await _handlePasswordLogin();
    } else {
      await _handleCookieLogin();
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (state.userName == null || state.password == null || state.userName!.isEmpty || state.password!.isEmpty) {
      snack('loginFail'.tr, 'userNameOrPasswordMismatch'.tr);
      return;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update();

    Map<String, dynamic> userInfoOrErrorMsg;
    try {
      userInfoOrErrorMsg = await EHRequest.requestLogin(
        state.userName!,
        state.password!,
        EHSpiderParser.loginPage2UserInfoOrErrorMsg,
      );
    } on DioError catch (e) {
      Log.error('loginFail'.tr, e.message);
      snack('loginFail'.tr, e.message);
      state.loginState = LoadingState.error;
      update();
      return;
    }

    if (userInfoOrErrorMsg['errorMsg'] == null) {
      state.loginState = LoadingState.success;
      UserSetting.saveUserInfo(
        userName: state.userName!,
        ipbMemberId: userInfoOrErrorMsg['ipbMemberId'],
        ipbPassHash: userInfoOrErrorMsg['ipbPassHash'],
      );
      FavoriteSetting.init();

      /// await DownWidget animation
      await Future.delayed(const Duration(milliseconds: 700));
      back(currentRoute: Routes.login);
    } else {
      state.loginState = LoadingState.error;
      snack('loginFail'.tr, userInfoOrErrorMsg['errorMsg']);
    }
    update();
  }

  Future<void> _handleCookieLogin() async {
    if (state.cookie == null || state.cookie!.isEmpty) {
      snack('loginFail'.tr, 'cookieIsBlack'.tr);
      return;
    }

    RegExpMatch? match = RegExp(r'ipb_member_id=(\w+).*ipb_pass_hash=(\w+)').firstMatch(state.cookie!);
    if (match == null) {
      snack('loginFail'.tr, 'cookieFormatError'.tr);
      return;
    }

    int ipbMemberId = int.parse(match.group(1)!);
    String ipbPassHash = match.group(2)!;
    cookieManager.storeEhCookiesForAllUri([
      Cookie('ipb_member_id', ipbMemberId.toString()),
      Cookie('ipb_pass_hash', ipbPassHash),
    ]);

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update();

    String? userName;
    try {
      /// get cookie [sk] first
      await EHRequest.requestHomePage();
      userName = await EHRequest.requestForum(ipbMemberId, EHSpiderParser.forumPage2UserInfo);
    } on DioError catch (e) {
      Log.error('loginFail'.tr, e.message);
      snack('loginFail'.tr, e.message);
      state.loginState = LoadingState.error;
      await cookieManager.removeAllCookies();
      update();
      return;
    }

    if (userName != null) {
      state.loginState = LoadingState.success;
      update();

      UserSetting.saveUserInfo(userName: userName, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);

      /// await DownWidget animation
      await Future.delayed(const Duration(milliseconds: 1000));
      back(currentRoute: Routes.login);
    } else {
      state.loginState = LoadingState.error;
      update();
      await cookieManager.removeAllCookies();
      snack('loginFail'.tr, 'invalidCookie'.tr);
    }
  }

  Future<void> handleWebLogin() async {
    toNamed(
      Routes.webview,
      arguments: {
        'url': EHConsts.ELogin,
        'onPageStarted': onLogin,
      },
    );
  }

  Future<void> onLogin(String url, WebViewController controller) async {
    String cookieString = await controller.runJavascriptReturningResult('document.cookie');
    cookieString = cookieString.replaceAll('"', '');
    if (!CookieUtil.validateCookiesString(cookieString)) {
      return;
    }

    List<Cookie> cookies = cookieString.split('; ').map((pair) {
      List<String> nameAndValue = pair.split('=');
      return Cookie(nameAndValue[0], nameAndValue[1]);
    }).toList();

    int ipbMemberId = int.parse(cookies.firstWhere((cookie) => cookie.name == 'ipb_member_id').value);
    String ipbPassHash = cookies.firstWhere((cookie) => cookie.name == 'ipb_pass_hash').value;

    /// temporarily
    UserSetting.userName.value = ipbMemberId.toString();
    until(
      currentRoute: Routes.webview,
      predicate: (route) => route.settings.name == Routes.settingAccount,
    );

    await cookieManager.storeEhCookiesForAllUri(cookies);
    String? userName = await EHRequest.requestForum(ipbMemberId, EHSpiderParser.forumPage2UserInfo);
    UserSetting.saveUserInfo(userName: userName!, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);
  }
}
