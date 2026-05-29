import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../exception/eh_site_exception.dart';
import '../../../../setting/eh_setting.dart';
import '../../../../utils/cookie_util.dart';
import '../../../../service/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
import 'login_page_state.dart';

class LoginPageLogic extends GetxController {
  static const formId = 'formId';
  static const cookieFormId = 'cookieFormId';
  static const cookieVerificationTypeId = 'cookieVerificationTypeId';
  static const loadingStateId = 'loadingStateId';

  final LoginPageState state = LoginPageState();

  void toggleLoginType() {
    state.loginType = (state.loginType == LoginType.cookie ? LoginType.password : LoginType.cookie);
    update([formId]);
  }

  Future<void> pasteCookie() async {
    String? cookie = (await Clipboard.getData('text/plain'))?.text?.toString();

    if (isEmptyOrNull(cookie)) {
      return;
    }

    RegExpMatch? match1 = RegExp(r'ipb_member_id[=:]\s?(\w+)').firstMatch(cookie!);
    RegExpMatch? match2 = RegExp(r'ipb_pass_hash[=:]\s?(\w+)').firstMatch(cookie);
    RegExpMatch? match3 = RegExp(r'igneous[=:]\s?(\w+)').firstMatch(cookie);

    String? ipbMemberId = match1?.group(1);
    String? ipbPassHash = match2?.group(1);
    String? igneous = match3?.group(1);

    if (ipbMemberId != null) {
      state.ipbMemberId = ipbMemberId;
    }
    if (ipbPassHash != null) {
      state.ipbPassHash = ipbPassHash;
    }
    if (igneous != null) {
      state.igneous = igneous;
    }

    updateSafely([cookieFormId]);
  }

  void handleLogin() {
    if (state.loginState == LoadingState.loading) {
      return;
    }

    if (state.loginType == LoginType.password) {
      _handlePasswordLogin();
    } else if (state.loginType == LoginType.cookie && state.cookieVerificationType == CookieVerificationType.normal) {
      _handleCookieLoginNormal();
    } else if (state.loginType == LoginType.cookie && state.cookieVerificationType == CookieVerificationType.webview) {
      _handleCookieLoginViaWebview();
    } else if (state.loginType == LoginType.cookie && state.cookieVerificationType == CookieVerificationType.skip) {
      _handleCookieLoginWithoutVerification();
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (state.userName == null || state.password == null || state.userName!.isEmpty || state.password!.isEmpty) {
      toast('userNameOrPasswordMismatch'.tr);
      return;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update([loadingStateId]);

    Map<String, dynamic> userInfoOrErrorMsg;
    try {
      userInfoOrErrorMsg = await ehRequest.requestLogin(
        state.userName!,
        state.password!,
        EHSpiderParser.loginPage2UserInfoOrErrorMsg,
      );
    } on DioException catch (e) {
      log.error('loginFail'.tr, e.errorMsg);
      snack('loginFail'.tr, e.errorMsg ?? '');
      state.loginState = LoadingState.error;
      update([loadingStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('loginFail'.tr, e.message);
      snack('loginFail'.tr, e.message);
      state.loginState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    if (userInfoOrErrorMsg['errorMsg'] != null) {
      log.info('Login failed by password.');
      snack('loginFail'.tr, (userInfoOrErrorMsg['errorMsg'] as String).tr, isShort: true);

      state.loginState = LoadingState.error;
      update([loadingStateId]);

      return ehRequest.requestLogout();
    }

    log.info('Login success by password.');

    userSetting.saveUserInfo(
      userName: state.userName!,
      ipbMemberId: userInfoOrErrorMsg['ipbMemberId'],
      ipbPassHash: userInfoOrErrorMsg['ipbPassHash'],
    );

    ehRequest
        .requestForum(
      userInfoOrErrorMsg['ipbMemberId'],
      EHSpiderParser.profilePage2UserInfo,
    )
        .then((userInfo) {
      userSetting.saveUserNameAndAvatarAndNickName(
        userName: userInfo!['userName']!,
        avatarImgUrl: userInfo['avatarImgUrl'],
        nickName: userInfo['nickName']!,
      );
    });

    state.loginState = LoadingState.success;
    update([loadingStateId]);

    toast('loginSuccess'.tr);
    backRoute(currentRoute: Routes.login);
  }

  Future<void> _handleCookieLoginNormal() async {
    if (isEmptyOrNull(state.ipbMemberId) || isEmptyOrNull(state.ipbPassHash)) {
      toast('cookieIsBlack'.tr);
      return;
    }

    await ehRequest.storeEHCookies([
      Cookie('ipb_member_id', state.ipbMemberId!),
      Cookie('ipb_pass_hash', state.ipbPassHash!),
    ]);

    bool useEXSite = false;
    if (state.igneous != null && state.igneous != '' && state.igneous != 'null' && state.igneous != 'mystery' && state.igneous != 'deleted') {
      await ehRequest.storeEHCookies([
        Cookie('igneous', state.igneous!),
      ]);
      useEXSite = true;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update([loadingStateId]);

    Map<String, String?>? userInfo;
    try {
      /// get cookie [sk] first
      await ehRequest.requestHomePage();
      userInfo = await ehRequest.requestForum(int.parse(state.ipbMemberId!), EHSpiderParser.profilePage2UserInfo);
    } on DioException catch (e) {
      log.error('loginFail'.tr, e.errorMsg);
      snack('loginFail'.tr, e.errorMsg ?? '', isShort: true);

      await ehRequest.removeAllCookies();

      state.loginState = LoadingState.error;
      update([loadingStateId]);
      return;
    } catch (e) {
      log.error('loginFail'.tr, e.toString());
      snack('loginFail'.tr, e.toString(), isShort: true);

      await ehRequest.removeAllCookies();

      state.loginState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    if (userInfo == null) {
      log.info('Login failed by cookie.');

      await ehRequest.removeAllCookies();

      state.loginState = LoadingState.error;
      update([loadingStateId]);

      snack('loginFail'.tr, 'invalidCookie'.tr);
      return;
    }

    log.info('Login success by cookie.');

    state.loginState = LoadingState.success;
    update([loadingStateId]);

    if (useEXSite) {
      ehSetting.site.value = 'EX';
    }
    userSetting.saveUserInfo(
      userName: userInfo['userName']!,
      ipbMemberId: int.parse(state.ipbMemberId!),
      ipbPassHash: state.ipbPassHash!,
      avatarImgUrl: userInfo['avatarImgUrl'],
      nickName: userInfo['nickName'],
    );

    toast('loginSuccess'.tr);
    backRoute(currentRoute: Routes.login);
  }

  Future<void> _handleCookieLoginViaWebview() async {
    if (isEmptyOrNull(state.ipbMemberId) || isEmptyOrNull(state.ipbPassHash)) {
      toast('cookieIsBlack'.tr);
      return;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update([loadingStateId]);

    await ehRequest.requestLogout();

    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      if (!await WebviewWindow.isWebviewAvailable()) {
        toast('webLoginIsDisabled'.tr);
        return;
      }

      Webview webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 800,
          windowHeight: 600,
          title: EHConsts.appName,
          userDataFolderWindows: pathService.getVisibleDir().path,
        ),
      );
      webview.addScriptToExecuteOnDocumentCreated('document.cookie = "ipb_member_id=${state.ipbMemberId}"');
      webview.addScriptToExecuteOnDocumentCreated('document.cookie = "ipb_pass_hash=${state.ipbPassHash}"');
      webview.isNavigating.addListener(() {
        if (!webview.isNavigating.value) {
          _onDesktopPageLoaded4CookieVerification(webview);
        }
      });
      webview.onClose.whenComplete(() {
        if (state.loginState == LoadingState.loading) {
          state.loginState = LoadingState.idle;
          update([loadingStateId]);
        }
      });

      webview.launch(EHConsts.EForums);
    } else {
      List<Cookie> cookies = [
        Cookie('ipb_member_id', state.ipbMemberId!),
        Cookie('ipb_pass_hash', state.ipbPassHash!),
      ];
      bool useExSite = false;
      if (state.igneous != null && state.igneous != '' && state.igneous != 'null' && state.igneous != 'mystery' && state.igneous != 'deleted') {
        await ehRequest.storeEHCookies([
          Cookie('igneous', state.igneous!),
        ]);
        useExSite = true;
      }

      toRoute(
        Routes.webview,
        arguments: {
          'title': 'login'.tr,
          'url': EHConsts.EForums,
          'cookies': CookieUtil.parse2String(cookies),
          'onPageFinished': (String url, WebViewController controller) => (_onMobilePageStarted4CookieVerification(url, controller, cookies, useExSite)),
        },
      )?.whenComplete(() {
        if (state.loginState == LoadingState.loading) {
          state.loginState = LoadingState.idle;
          update([loadingStateId]);
        }
      });
    }
  }

  Future<void> _onDesktopPageLoaded4CookieVerification(Webview webview) async {
    String href = await webview.evaluateJavaScript('window.location.href') as String;
    if (!href.contains(EHConsts.EForums)) {
      return;
    }

    String? rawGuestHint = await webview.evaluateJavaScript('''
    document.querySelector('#userlinksguest')?.innerText ?? ""
    ''');
    
    String guestHint;
    try {
      guestHint = jsonDecode(rawGuestHint!);
    } catch (e) {
      guestHint = rawGuestHint!;
    }

    bool loginFailed = !isEmptyOrNull(guestHint) && guestHint != 'null';
    if (loginFailed) {
      log.info('Login failed by cookie via webview.');

      state.loginState = LoadingState.error;
      update([loadingStateId]);
      snack('loginFail'.tr, 'invalidCookie'.tr);
      webview.close();
      return;
    }

    String? rawUsername = await webview.evaluateJavaScript('''
    document.querySelector('.home > b > a')?.innerText ?? ""
    ''');

    String username;
    try {
      username = jsonDecode(rawUsername!);
    } catch (e) {
      username = rawUsername!;
    }
    if (isEmptyOrNull(username) || username == 'null') {
      return;
    }

    await ehRequest.storeEHCookies([
      Cookie('ipb_member_id', state.ipbMemberId!),
      Cookie('ipb_pass_hash', state.ipbPassHash!),
    ]);
    if (state.igneous != null && state.igneous != '' && state.igneous != 'null' && state.igneous != 'mystery' && state.igneous != 'deleted') {
      await ehRequest.storeEHCookies([
        Cookie('igneous', state.igneous!),
      ]);
      ehSetting.site.value = 'EX';
    }
    await userSetting.saveUserInfo(
      userName: username,
      ipbMemberId: int.parse(state.ipbMemberId!),
      ipbPassHash: state.ipbPassHash!,
    );

    log.info('Login success by web via webview.');
    state.loginState = LoadingState.success;
    update([loadingStateId]);
    toast('loginSuccess'.tr);
    webview.close();

    untilRoute(
      currentRoute: Routes.login,
      predicate: (route) => route.settings.name == Routes.settingAccount || route.settings.name == Routes.blank || route.settings.name == Routes.home,
    );
  }

  Future<void> _onMobilePageStarted4CookieVerification(String url, WebViewController controller, List<Cookie> cookies, bool useExSite) async {
    if (url != EHConsts.EForums) {
      return;
    }

    String? rawGuestHint = await controller.runJavaScriptReturningResult('''
    document.querySelector('#userlinksguest')?.innerText ?? ""
    ''') as String?;

    String guestHint;
    try {
      guestHint = jsonDecode(rawGuestHint!);
    } catch (e) {
      guestHint = rawGuestHint!;
    }
    
    bool loginFailed = !isEmptyOrNull(guestHint) && guestHint != 'null';
    if (loginFailed) {
      log.info('Login failed by cookie via webview.');

      state.loginState = LoadingState.error;
      update([loadingStateId]);
      snack('loginFail'.tr, 'invalidCookie'.tr);
      backRoute(currentRoute: Routes.webview);
      return;
    }

    String? rawUsername = await controller.runJavaScriptReturningResult('''
    document.querySelector('.home > b > a')?.innerText ?? ""
    ''') as String?;

    String username;
    try {
      username = jsonDecode(rawUsername!);
    } catch (e) {
      username = rawUsername!;
    }
    if (isEmptyOrNull(username) || username == 'null') {
      return;
    }
    
    await ehRequest.storeEHCookies(cookies);
    if (useExSite) {
      ehSetting.site.value = 'EX';
    }
    await userSetting.saveUserInfo(
      userName: username,
      ipbMemberId: int.parse(state.ipbMemberId!),
      ipbPassHash: state.ipbPassHash!,
    );

    log.info('Login success by web via webview.');
    state.loginState = LoadingState.success;
    update([loadingStateId]);
    toast('loginSuccess'.tr);
    untilRoute(
      currentRoute: Routes.webview,
      predicate: (route) => route.settings.name == Routes.settingAccount || route.settings.name == Routes.home,
    );
  }

  Future<void> _handleCookieLoginWithoutVerification() async {
    if (isEmptyOrNull(state.ipbMemberId) || isEmptyOrNull(state.ipbPassHash)) {
      toast('cookieIsBlack'.tr);
      return;
    }

    ehRequest.storeEHCookies([
      Cookie('ipb_member_id', state.ipbMemberId!),
      Cookie('ipb_pass_hash', state.ipbPassHash!),
    ]);

    bool useEXSite = false;
    if (state.igneous != null && state.igneous != '' && state.igneous != 'null' && state.igneous != 'mystery' && state.igneous != 'deleted') {
      ehRequest.storeEHCookies([
        Cookie('igneous', state.igneous!),
      ]);
      useEXSite = true;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    log.info('Login success by cookie without verification.');

    state.loginState = LoadingState.success;
    update([loadingStateId]);

    if (useEXSite) {
      ehSetting.site.value = 'EX';
    }
    userSetting.saveUserInfo(
      userName: 'EHUser'.tr,
      ipbMemberId: int.parse(state.ipbMemberId!),
      ipbPassHash: state.ipbPassHash!,
      avatarImgUrl: null,
      nickName: null,
    );

    toast('loginSuccess'.tr);
    backRoute(currentRoute: Routes.login);
  }

  Future<void> handleWebLogin() async {
    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      if (!await WebviewWindow.isWebviewAvailable()) {
        toast('webLoginIsDisabled'.tr);
        return;
      }
      Webview webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 800,
          windowHeight: 600,
          title: EHConsts.appName,
          userDataFolderWindows: pathService.getVisibleDir().path,
        ),
      );
      webview.addOnUrlRequestCallback((url) {
        _onDesktopPageStarted4WebLogin(webview, url);
      });
      webview.launch(EHConsts.ELogin);
    } else {
      toRoute(
        Routes.webview,
        arguments: {
          'title': 'login'.tr,
          'url': EHConsts.ELogin,
          'onPageStarted': _onMobilePageStarted4WebLogin,
        },
      );
    }
  }

  Future<void> _onDesktopPageStarted4WebLogin(Webview webview, String url) async {
    if (state.cookieLoginLoadingState != LoadingState.idle) {
      return;
    }

    String cookieString = await webview.evaluateJavaScript('document.cookie') as String;
    cookieString = cookieString.replaceAll('"', '');
    if (!CookieUtil.validateCookiesString(cookieString)) {
      return;
    }

    log.info('Login success by web.');
    state.cookieLoginLoadingState = LoadingState.loading;

    try {
      List<Cookie> cookies = CookieUtil.parse2Cookies(cookieString);
      ehRequest.storeEHCookies(CookieUtil.parse2Cookies(cookieString));

      int ipbMemberId = int.parse(cookies.firstWhere((cookie) => cookie.name == 'ipb_member_id').value);
      String ipbPassHash = cookies.firstWhere((cookie) => cookie.name == 'ipb_pass_hash').value;

      /// temporary name
      userSetting.saveUserInfo(userName: 'EHUser'.tr, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);

      webview.close();
      toast('loginSuccess'.tr);
      untilRoute(
        currentRoute: Routes.login,
        predicate: (route) => route.settings.name == Routes.settingAccount || route.settings.name == Routes.blank || route.settings.name == Routes.home,
      );

      /// get username and avatar
      Map<String, String?>? userInfo = await ehRequest.requestForum(ipbMemberId, EHSpiderParser.profilePage2UserInfo);
      userSetting.saveUserNameAndAvatarAndNickName(
        userName: userInfo!['userName']!,
        avatarImgUrl: userInfo['avatarImgUrl'],
        nickName: userInfo['nickName']!,
      );

      state.cookieLoginLoadingState = LoadingState.success;
    } finally {
      state.cookieLoginLoadingState = LoadingState.idle;
    }
  }

  Future<void> _onMobilePageStarted4WebLogin(String url, WebViewController controller) async {
    if (state.cookieLoginLoadingState != LoadingState.idle) {
      return;
    }

    String cookieString = await controller.runJavaScriptReturningResult('document.cookie') as String;
    cookieString = cookieString.replaceAll('"', '');
    if (!CookieUtil.validateCookiesString(cookieString)) {
      return;
    }

    log.info('Login success by web.');
    state.cookieLoginLoadingState = LoadingState.loading;

    try {
      List<Cookie> cookies = CookieUtil.parse2Cookies(cookieString);
      ehRequest.storeEHCookies(CookieUtil.parse2Cookies(cookieString));

      int ipbMemberId = int.parse(cookies.firstWhere((cookie) => cookie.name == 'ipb_member_id').value);
      String ipbPassHash = cookies.firstWhere((cookie) => cookie.name == 'ipb_pass_hash').value;

      /// temporary name
      userSetting.saveUserInfo(userName: 'EHUser'.tr, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);

      toast('loginSuccess'.tr);
      untilRoute(
        currentRoute: Routes.webview,
        predicate: (route) => route.settings.name == Routes.settingAccount || route.settings.name == Routes.home,
      );

      /// get username and avatar
      Map<String, String?>? userInfo = await ehRequest.requestForum(ipbMemberId, EHSpiderParser.profilePage2UserInfo);
      userSetting.saveUserNameAndAvatarAndNickName(
        userName: userInfo!['userName']!,
        avatarImgUrl: userInfo['avatarImgUrl'],
        nickName: userInfo['nickName']!,
      );

      state.cookieLoginLoadingState = LoadingState.success;
    } finally {
      state.cookieLoginLoadingState = LoadingState.idle;
    }
  }
}
