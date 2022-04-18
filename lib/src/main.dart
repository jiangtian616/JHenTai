import 'dart:async';
import 'package:blur/blur.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'exception/upload_exception.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
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
import 'network/eh_cookie_manager.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    Log.error(details.exception, null, details.stack);
    Log.upload(details.exception, stackTrace: details.stack);
  };

  runZonedGuarded(() async {
    await init();
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    if (error is UploadException) {
      return;
    }
    Log.error(error, null, stack);
    Log.upload(error, stackTrace: stack);
  });
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
      locale: StyleSetting.locale.value,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: SecuritySetting.enableFingerPrintLock.isTrue ? Routes.lock : Routes.start,
      navigatorObservers: [GetXRouterObserver(), SentryNavigatorObserver()],
      builder: (context, child) => AppListener(child: child!),

      /// enable swipe back feature
      popGesture: true,
      onReady: onReady,
    );
  }
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? dsn;
  try {
    dsn = await rootBundle.loadString('assets/sentry_dsn');
  } catch (_) {}
  if (dsn != null && !kDebugMode) {
    await SentryFlutter.init((options) => options.dsn = dsn);
  }

  await PathSetting.init();

  await GetStorage.init(StorageService.storageFileName);
  StorageService.init();

  await AdvancedSetting.init();
  await SecuritySetting.init();
  await Log.init();
  UserSetting.init();
  TagTranslationService.init();
  StyleSetting.init();
  TabBarSetting.init();
  HistoryService.init();

  SiteSetting.init();
  FavoriteSetting.init();

  EHSetting.init();

  await EHCookieManager.init();

  DownloadSetting.init();
  await EHRequest.init();

  await ArchiveDownloadService.init();
  await GalleryDownloadService.init();
}

Future<void> onReady() async {
  FavoriteSetting.refresh();
  SiteSetting.refresh();
  EHSetting.refresh();

  ReadSetting.init();
}

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(AppLifecycleState state);

class AppListener extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback> _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback> _didChangeAppLifecycleStateCallbacks = [];

  final Widget child;

  const AppListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AppListener> createState() => _AppListenerState();

  static void registerDidChangePlatformBrightnessCallback(DidChangePlatformBrightnessCallback callback) {
    _didChangePlatformBrightnessCallbacks.add(callback);
  }

  static void registerDidChangeAppLifecycleStateCallback(DidChangeAppLifecycleStateCallback callback) {
    _didChangeAppLifecycleStateCallbacks.add(callback);
  }
}

class _AppListenerState extends State<AppListener> with WidgetsBindingObserver {
  AppLifecycleState _state = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    AppListener.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppListener.registerDidChangeAppLifecycleStateCallback(_blurAppPage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    for (DidChangePlatformBrightnessCallback callback in AppListener._didChangePlatformBrightnessCallbacks) {
      callback.call();
    }
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (DidChangeAppLifecycleStateCallback callback in AppListener._didChangeAppLifecycleStateCallbacks) {
      callback.call(state);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isAndroid || _state == AppLifecycleState.resumed) {
      return widget.child;
    }
    return Blur(blur: 100, child: widget.child);
  }

  void _changeTheme() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    Get.changeThemeMode(
      WidgetsBinding.instance?.window.platformBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void _blurAppPage(AppLifecycleState state) {
    if (SecuritySetting.enableBlur.isFalse) {
      return;
    }

    /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
    /// so i choose to set FLAG_SECURE to do the same effect.
    if (state == AppLifecycleState.inactive) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        setState(() {
          _state = state;
        });
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);

        /// resume appbar color
        SystemChrome.setSystemUIOverlayStyle(
            Get.theme.appBarTheme.systemOverlayStyle!.copyWith(systemStatusBarContrastEnforced: true));
      } else {
        setState(() {
          _state = state;
        });
      }
    }
  }
}
