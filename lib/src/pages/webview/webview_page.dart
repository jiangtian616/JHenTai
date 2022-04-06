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

typedef OnPageStartedCallback = Future<void> Function(String url, WebViewController controller);

class WebviewPage extends StatefulWidget {
  const WebviewPage({Key? key}) : super(key: key);

  @override
  _WebviewPageState createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late WebViewController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: WebView(
        initialUrl: Get.arguments['url'],
        onWebViewCreated: (controller) => this.controller = controller,
        javascriptMode: JavascriptMode.unrestricted,
        initialCookies: CookieUtil.parse2Cookies(Get.arguments['cookies'])
            .map((cookie) =>
                WebViewCookie(name: cookie.name, value: cookie.value, domain: Uri.parse(Get.arguments['url']).host))
            .toList(),
        onPageStarted: (url) => Get.arguments['onPageStarted']?.call(url, controller),
      ),
    );
  }
}
