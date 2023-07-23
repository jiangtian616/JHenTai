import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/sentry_config.dart';
import 'package:jhentai/src/service/app_update_service.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/relogin_service.dart';
import 'package:jhentai/src/service/search_history_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/service/windows_service.dart';
import 'package:jhentai/src/setting/frame_rate_setting.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/widget/app_manager.dart';
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
      themeMode: StyleSetting.themeMode.value,
      theme: ThemeConfig.generateThemeData(StyleSetting.lightThemeColor.value, Brightness.light),
      darkTheme: ThemeConfig.generateThemeData(StyleSetting.darkThemeColor.value, Brightness.dark),

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
      initialRoute: SecuritySetting.enablePasswordAuth.isTrue || SecuritySetting.enableBiometricAuth.isTrue ? Routes.lock : Routes.home,
      navigatorObservers: [GetXRouterObserver(), SentryNavigatorObserver()],
      builder: (context, child) => AppManager(child: child!),

      /// enable swipe back feature
      popGesture: PreferenceSetting.enableSwipeBackGesture.isTrue,
      onReady: onReady,
    );
  }
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  if (SentryConfig.dsn.isNotEmpty && !kDebugMode) {
    await SentryFlutter.init((options) => options.dsn = SentryConfig.dsn);
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is NotUploadException) {
      return true;
    }

    Log.error('Global Error', error, stack);
    Log.upload(error, stackTrace: stack);
    return false;
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is NotUploadException) {
      return;
    }

    Log.error(details.exception, null, details.stack);
    Log.upload(details.exception, stackTrace: details.stack);
  };

  await FrameRateSetting.init();

  await PathSetting.init();
  AppUpdateService.init();
  await StorageService.init();

  StyleSetting.init();
  NetworkSetting.init();
  await AdvancedSetting.init();
  await SecuritySetting.init();
  await Log.init();
  UserSetting.init();

  TabBarSetting.init();
  WindowService.init();

  SiteSetting.init();
  FavoriteSetting.init();
  MyTagsSetting.init();
  EHSetting.init();

  await EHCookieManager.init();
  EHCacheInterceptor.init();

  ReLoginService.init();

  DownloadSetting.init();
  await EHRequest.init();
  
  PreferenceSetting.init();
  
  TagTranslationService.init();

  MouseSetting.init();

  QuickSearchService.init();

  HistoryService.init();
  SearchHistoryService.init();
  GalleryDownloadService.init();
  ArchiveDownloadService.init();
  LocalGalleryService.init();
  SuperResolutionSetting.init();
  SuperResolutionService.init();
}

Future<void> onReady() async {
  FavoriteSetting.refresh();
  SiteSetting.refresh();
  EHSetting.refresh();
  MyTagsSetting.refreshOnlineTagSets();

  ReadSetting.init();
  
  VolumeService.init();
}

void _doForDesktop() {
  if (!GetPlatform.isDesktop) {
    return;
  }

  doWhenWindowReady(() {
    WindowService windowService = Get.find();

    appWindow.title = 'JHenTai';
    appWindow.size = Size(windowService.windowWidth, windowService.windowHeight);
    if (windowService.isMaximized) {
      appWindow.maximize();
    }
    // https://github.com/bitsdojo/bitsdojo_window/issues/193
    else if (GetPlatform.isWindows && kDebugMode) {
      WidgetsBinding.instance.scheduleFrameCallback((_) => appWindow.size += const Offset(1, 0));
    }

    appWindow.show();
  });
}
