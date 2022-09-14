import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/state_extension.dart';
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
  late final String initialUrl;
  late final List<WebViewCookie> initialCookies;
  late final Function? pageStartedCallback;
  late final PageStartedCallback onPageStarted;

  late final WebViewController controller;

  LoadingState loadingState = LoadingState.loading;

  @override
  void initState() {
    super.initState();
    title = Get.arguments['title'];
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
      appBar: AppBar(
        elevation: 1,
        title: LoadingStateIndicator(
          loadingState: loadingState,
          successWidgetBuilder: () => Text(title),
        ).paddingOnly(right: 40),
      ),
      body: WebView(
        initialUrl: initialUrl,
        onWebViewCreated: (controller) => this.controller = controller,
        javascriptMode: JavascriptMode.unrestricted,
        initialCookies: initialCookies,
        onPageStarted: onPageStarted,
        onPageFinished: (_) => setStateIfMounted(() => loadingState = LoadingState.success),
        onWebResourceError: (_) => setStateIfMounted(() => loadingState = LoadingState.success),
      ),
    );
  }
}
