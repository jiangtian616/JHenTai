import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../utils/log.dart';
import 'login_page_state.dart';

class LoginPageLogic extends GetxController {
  final LoginPageState state = LoginPageState();

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
      Get.snackbar(
        'loginFail'.tr,
        'userNameOrPasswordMismatch'.tr,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey.withOpacity(0.7),
      );
      return;
    }

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update();

    String? errorMsg;
    try {
      errorMsg = await EHRequest.login(state.userName!, state.password!);
    } on DioError catch (e) {
      Log.error(e);
      Get.snackbar('loginFail'.tr, e.message);
      state.loginState = LoadingState.error;
      update();
      return;
    }

    if (errorMsg == null) {
      state.loginState = LoadingState.success;

      FavoriteSetting.init();
      /// await DownWidget animation
      await Future.delayed(const Duration(milliseconds: 700));
      Get.back();
    } else {
      state.loginState = LoadingState.error;
      Get.snackbar(
        'loginFail'.tr,
        errorMsg,
        backgroundColor: Colors.grey.withOpacity(0.7),
      );
    }
    update();
  }

  Future<void> _handleCookieLogin() async {
    if (state.cookie == null || state.cookie!.isEmpty) {
      Get.snackbar(
        'loginFail'.tr,
        'cookieIsBlack'.tr,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey.withOpacity(0.7),
      );
      return;
    }

    RegExpMatch? match = RegExp(r'ipb_member_id=(\w+).*ipb_pass_hash=(\w+)').firstMatch(state.cookie!);
    if (match == null) {
      Get.snackbar(
        'loginFail'.tr,
        'cookieFormatError'.tr,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey.withOpacity(0.7),
      );
      return;
    }

    int ipbMemberId = int.parse(match.group(1)!);
    String ipbPassHash = match.group(2)!;
    EHRequest.storeEhCookiesForAllUri([
      Cookie('ipb_member_id', ipbMemberId.toString()),
      Cookie('ipb_pass_hash', ipbPassHash),
    ]);

    /// control mobile keyboard
    Get.focusScope?.unfocus();

    state.loginState = LoadingState.loading;
    update();

    List<String?>? userNameAndAvatarUrl;
    try {
      userNameAndAvatarUrl = await EHRequest.getUserInfoByCookieAndMemberId(ipbMemberId);
    } on DioError catch (e) {
      Log.error(e);
      Get.snackbar('loginFail'.tr, e.message);
      state.loginState = LoadingState.error;
      await EHRequest.removeAllCookies();
      update();
      return;
    }

    if (userNameAndAvatarUrl != null) {
      state.loginState = LoadingState.success;
      update();

      UserSetting.saveUserInfo(userName: userNameAndAvatarUrl[0]!, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);

      /// await DownWidget animation
      await Future.delayed(const Duration(milliseconds: 1000));
      Get.back();
    } else {
      state.loginState = LoadingState.error;
      update();
      await EHRequest.removeAllCookies();
      Get.snackbar(
        'loginFail'.tr,
        'invalidCookie'.tr,
        backgroundColor: Colors.grey.withOpacity(0.7),
      );
    }
  }
}
