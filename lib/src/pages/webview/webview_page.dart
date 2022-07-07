import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef OnPageStartedCallback = Future<void> Function(String url, WebViewController controller);

class WebviewPage extends StatefulWidget {
  const WebviewPage({Key? key}) : super(key: key);

  @override
  _WebviewPageState createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late String initialUrl;
  late List<WebViewCookie> initialCookies;
  Function? pageStartedCallback;
  late PageStartedCallback onPageStarted;

  late WebViewController controller;

  @override
  void initState() {
    super.initState();
    initialUrl = Get.arguments['url'];
    initialCookies = CookieUtil.parse2Cookies(Get.arguments['cookies'])
        .map(
          (cookie) => WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: Uri.parse(Get.arguments['url']).host,
          ),
        )
        .toList();
    pageStartedCallback = Get.arguments['onPageStarted'];
    onPageStarted = (url) {
      pageStartedCallback?.call(url, controller);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: WebView(
        initialUrl: initialUrl,
        onWebViewCreated: (controller) => this.controller = controller,
        javascriptMode: JavascriptMode.unrestricted,
        initialCookies: initialCookies,
        onPageStarted: onPageStarted,
      ),
    );
  }
}
