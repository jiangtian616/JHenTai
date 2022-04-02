import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/route_util.dart';

class WebviewPage extends StatefulWidget {
  const WebviewPage({Key? key}) : super(key: key);

  @override
  _WebviewPageState createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late String url;
  late WebViewController controller;
  late List<Cookie> cookies;

  bool isLogin = false;

  @override
  void initState() {
    url = Get.arguments;
    isLogin = Get.parameters['isLogin'] == 'true';
    cookies = CookieUtil.parse2Cookies(Get.parameters['cookies']);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: WebView(
        initialUrl: url,
        onWebViewCreated: (controller) => this.controller = controller,
        javascriptMode: JavascriptMode.unrestricted,
        initialCookies: cookies
            .map((cookie) => WebViewCookie(name: cookie.name, value: cookie.value, domain: Uri.parse(url).host))
            .toList(),
        onPageStarted: isLogin ? onLogin : null,
      ),
    );
  }

  Future<void> onLogin(String url) async {
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
      Routes.webview,
      (route) => route.settings.name == Routes.settingAccount,
    );

    await EHRequest.storeEhCookiesForAllUri(cookies);
    String? userName = await EHRequest.requestForum(ipbMemberId, EHSpiderParser.forumPage2UserInfo);
    UserSetting.saveUserInfo(userName: userName!, ipbMemberId: ipbMemberId, ipbPassHash: ipbPassHash);
  }
}
