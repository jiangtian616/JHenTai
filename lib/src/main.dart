import 'dart:async';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/widget/app_manager.dart';
import 'exception/upload_exception.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/service/log.dart';

import 'config/theme_config.dart';

List<JHLifeCircleBean> lifeCircleBeans = [];

List<JHLifeCircleBean> topologicalSort(List<JHLifeCircleBean> lifeCircleBeans) {
  // Maps to store the visiting state and result order
  final visiting = <JHLifeCircleBean, bool>{};
  final visited = <JHLifeCircleBean, bool>{};
  final result = <JHLifeCircleBean>[];

  // Helper function for DFS
  void visit(JHLifeCircleBean node) {
    if (visited.containsKey(node)) {
      return;
    }
    if (visiting[node] == true) {
      throw Exception('Circular dependency detected');
    }
    visiting[node] = true;
    for (final dependency in node.initDependencies) {
      visit(dependency);
    }
    visiting[node] = false;
    visited[node] = true;
    result.add(node);
  }

  // Visit all nodes
  for (final node in lifeCircleBeans) {
    visit(node);
  }

  return result.toList();
}

void main(List<String> args) async {
  if (GetPlatform.isDesktop && runWebViewTitleBarWidget(args)) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is NotUploadException) {
      return true;
    }

    log.error('Global Error', error, stack);
    log.uploadError(error, stackTrace: stack);
    return false;
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is NotUploadException) {
      return;
    }

    log.error('Global Error', details.exception, details.stack);
    log.uploadError(details.exception, stackTrace: details.stack);
  };

  lifeCircleBeans = topologicalSort(lifeCircleBeans);
  for (JHLifeCircleBean bean in lifeCircleBeans) {
    await bean.onInit();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JHenTai',
      themeMode: styleSetting.themeMode.value,
      theme: ThemeConfig.theme(styleSetting.lightThemeColor.value, Brightness.light),
      darkTheme: ThemeConfig.theme(styleSetting.darkThemeColor.value, Brightness.dark),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('ko', 'KR'),
        Locale('pt', 'BR'),
      ],
      locale: preferenceSetting.locale.value,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: securitySetting.enablePasswordAuth.isTrue || securitySetting.enableBiometricAuth.isTrue ? Routes.lock : Routes.home,
      navigatorObservers: [GetXRouterObserver()],
      builder: (context, child) => AppManager(child: child!),

      /// enable swipe back feature
      popGesture: preferenceSetting.enableSwipeBackGesture.isTrue,
      onReady: () {
        for (JHLifeCircleBean bean in lifeCircleBeans) {
          bean.onReady();
        }
      },
    );
  }
}
