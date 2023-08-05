import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef OnPageStartedCallback = Future<void> Function(String url, WebViewController controller);

class WebviewPage extends StatefulWidget {
  const WebviewPage({Key? key}) : super(key: key);

  @override
  _WebviewPageState createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late final String title;
  late final Function? pageStartedCallback;
  late final WebViewController controller;

  LoadingState loadingState = LoadingState.loading;

  @override
  void initState() {
    super.initState();

    title = Get.arguments['title'];

    if (Get.arguments is Map && Get.arguments['onPageStarted'] is Function) {
      pageStartedCallback = Get.arguments['onPageStarted'];
    } else {
      pageStartedCallback = null;
    }

    CookieUtil.parse2Cookies(Get.arguments['cookies']).forEach((cookie) {
      WebViewCookieManager().setCookie(
        WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: Uri.parse(Get.arguments['url']).host,
        ),
      );
    });

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            pageStartedCallback?.call(url, controller);
          },
          onPageFinished: (_) => setStateSafely(() => loadingState = LoadingState.success),
          onWebResourceError: (_) => setStateSafely(() => loadingState = LoadingState.success),
        ),
      )
      ..loadRequest(Uri.parse(Get.arguments['url']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: LoadingStateIndicator(
          loadingState: loadingState,
          successWidgetBuilder: () => Text(title),
        ).paddingOnly(right: 40),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
