import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/sentry_config.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/relogin_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/service/windows_service.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/widget/app_state_listener.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';

import 'config/theme_config.dart';
import 'network/eh_cache_interceptor.dart';
import 'network/eh_cookie_manager.dart';

void main() async {
  await init();

  runApp(const MyApp());

  _doForDesktop();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JHenTai',
      theme: ThemeConfig.light,
      darkTheme: ThemeConfig.dark,
      themeMode: StyleSetting.themeMode.value,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      locale: StyleSetting.locale.value,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: SecuritySetting.enableBiometricLock.isTrue ? Routes.lock : Routes.home,
      navigatorObservers: [GetXRouterObserver(), SentryNavigatorObserver()],
      builder: (context, child) => AppStateListener(child: child!),

      /// enable swipe back feature
      popGesture: true,
      onReady: onReady,
    );
  }
}

Future<void> init() async {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  FlutterError.onError = (FlutterErrorDetails details) {
    Log.error(details.exception, null, details.stack);
    Log.upload(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is NotUploadException) {
      return true;
    }

    Log.error('Global Error', error, stack);
    Log.upload(error, stackTrace: stack);
    return false;
  };

  WidgetsFlutterBinding.ensureInitialized();

  if (SentryConfig.dsn.isNotEmpty && !kDebugMode) {
    await SentryFlutter.init((options) => options.dsn = SentryConfig.dsn);
  }

  await PathSetting.init();
  await StorageService.init();

  NetworkSetting.init();
  await AdvancedSetting.init();
  await SecuritySetting.init();
  await Log.init();
  UserSetting.init();
  TagTranslationService.init();
  StyleSetting.init();
  TabBarSetting.init();
  WindowService.init();

  SiteSetting.init();
  FavoriteSetting.init();

  EHSetting.init();

  await EHCookieManager.init();
  EHCacheInterceptor.init();

  ReLoginService.init();

  DownloadSetting.init();
  await EHRequest.init();

  MouseSetting.init();

  QuickSearchService.init();

  HistoryService.init();
  GalleryDownloadService.init();
}

Future<void> onReady() async {
  FavoriteSetting.refresh();
  SiteSetting.refresh();
  EHSetting.refresh();

  ReadSetting.init();

  ArchiveDownloadService.init();
  LocalGalleryService.init();

  VolumeService.init();
}

void _doForDesktop() {
  if (!GetPlatform.isDesktop) {
    return;
  }

  doWhenWindowReady(() {
    appWindow.title = 'JHenTai';
    appWindow.size = const Size(1280, 720);

    if (Get.find<StorageService>().read('windowMaximize') == true) {
      appWindow.maximize();
    }

    appWindow.show();
  });
}
