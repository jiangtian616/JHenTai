import 'dart:ui';
import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';


void main() async {
  FlutterError.presentError = (FlutterErrorDetails details, {bool forceReport = false}) => Log.error(details.exception);

  runZonedGuarded(() async {
    await beforeInit();
    runApp(DevicePreview(
      enabled: false,
      builder: (context) => const MyApp(),
    ));
  }, (Object error, StackTrace stack) {
    Log.error(error);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JHenTai',
      theme: StyleSetting.getCurrentThemeData(),

      locale: window.locale,
      fallbackLocale: const Locale('en', 'US'),
      translations: LocaleText(),

      getPages: Routes.pages,
      initialRoute: Routes.start,
      navigatorObservers: [GetXRouterObserver()],

      /// device preview
      useInheritedMediaQuery: true,
      // locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      /// enable swipe back feature
      popGesture: true,
      onReady: onReady,
    );
  }
}

Future<void> beforeInit() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PathSetting.init();

  await GetStorage.init();
  StorageService.init();

  AdvancedSetting.init();
  await Log.init();
  UserSetting.init();
  TagTranslationService.init();
  StyleSetting.init();
  TabBarSetting.init();

  SiteSetting.init();
  FavoriteSetting.init();

  EHSetting.init();

  DownloadSetting.init();
  await EHRequest.init();

  await DownloadService.init();

  TagTranslationService.init();
}

Future<void> onReady() async {
  FavoriteSetting.refresh();
  SiteSetting.refresh();

  ReadSetting.init();
}
