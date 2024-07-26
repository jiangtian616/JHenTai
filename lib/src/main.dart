import 'dart:async';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/jh_request.dart';
import 'package:jhentai/src/service/app_update_service.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/schedule_service.dart';
import 'package:jhentai/src/service/search_history_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/tag_search_order_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/service/windows_service.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/performance_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/widget/app_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'exception/upload_exception.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';

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

  await init();

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
      locale: PreferenceSetting.locale.value,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: securitySetting.enablePasswordAuth.isTrue || securitySetting.enableBiometricAuth.isTrue ? Routes.lock : Routes.home,
      navigatorObservers: [GetXRouterObserver()],
      builder: (context, child) => AppManager(child: child!),

      /// enable swipe back feature
      popGesture: PreferenceSetting.enableSwipeBackGesture.isTrue,
      onReady: onReady,
    );
  }
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (GetPlatform.isDesktop) {
    await windowManager.ensureInitialized();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is NotUploadException) {
      return true;
    }

    Log.error('Global Error', error, stack);
    Log.uploadError(error, stackTrace: stack);
    return false;
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is NotUploadException) {
      return;
    }

    Log.error('Global Error', details.exception, details.stack);
    Log.uploadError(details.exception, stackTrace: details.stack);
  };

  lifeCircleBeans = topologicalSort(lifeCircleBeans);
  for (JHLifeCircleBean bean in lifeCircleBeans) {
    await bean.onInit();
  }

  AppUpdateService.init();

  await Log.init();
  UserSetting.init();

  TabBarSetting.init();
  WindowService.init();

  SiteSetting.init();
  FavoriteSetting.init();
  MyTagsSetting.init();
  EHSetting.init();

  DownloadSetting.init();
  await EHRequest.init();
  await JHRequest.init();

  PreferenceSetting.init();

  TagTranslationService.init();
  TagSearchOrderOptimizationService.init();

  MouseSetting.init();

  QuickSearchService.init();

  HistoryService.init();
  SearchHistoryService.init();
  PerformanceSetting.init();
  GalleryDownloadService.init();
  ArchiveDownloadService.init();
  LocalGalleryService.init();
  SuperResolutionSetting.init();
  SuperResolutionService.init();

  ReadSetting.init();

  LocalBlockRuleService.init();

  if (GetPlatform.isDesktop) {
    WindowService windowService = Get.find();

    WindowOptions windowOptions = WindowOptions(
      center: true,
      size: Size(windowService.windowWidth, windowService.windowHeight),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'JHenTai',
      titleBarStyle: GetPlatform.isWindows ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (PreferenceSetting.launchInFullScreen.isTrue) {
        await windowManager.setFullScreen(true);
      }
      if (windowService.isMaximized) {
        await windowManager.maximize();
      }
      windowService.inited = true;
    });
  }
}

Future<void> onReady() async {
  for (JHLifeCircleBean bean in lifeCircleBeans) {
    bean.onReady();
  }

  FavoriteSetting.refresh();
  SiteSetting.refresh();
  EHSetting.refresh();
  MyTagsSetting.refreshAllOnlineTagSets();

  VolumeService.init();

  CloudConfigService.init();

  ScheduleService.init();
}
