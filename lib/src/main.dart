import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/network/jh_request.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:jhentai/src/routes/getx_router_observer.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/app_update_service.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/built_in_blocked_user_service.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/service/frame_rate_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/read_progress_service.dart';
import 'package:jhentai/src/service/schedule_service.dart';
import 'package:jhentai/src/service/search_history_service.dart';
import 'package:jhentai/src/service/smart_cache_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/service/tag_search_order_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:jhentai/src/service/windows_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/keyboard_shortcut_setting.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/performance_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/inference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/widget/app_manager.dart';

import 'config/theme_config.dart';
import 'network/archive_bot_request.dart';
import 'service/inference_service.dart';
import 'service/lan_device_trust_service.dart';
import 'service/lan_sharing_runtime.dart';

List<JHLifeCircleBean> lifeCircleBeans = [
  ehRequest,
  jhRequest,
  archiveBotRequest,
  appUpdateService,
  galleryDownloadService,
  archiveDownloadService,
  localGalleryService,
  cloudConfigService,
  frameRateService,
  historyService,
  isolateService,
  localBlockRuleService,
  localConfigService,
  readProgressService,
  log,
  pathService,
  quickSearchService,
  scheduleService,
  searchHistoryService,
  smartCacheService,
  storageService,
  superResolutionService,
  imageTranslationService,
  lanDeviceTrustService,
  lanSharingRuntime,
  inferenceService,
  tagTranslationService,
  tagSearchOrderOptimizationService,
  volumeService,
  windowService,
  advancedSetting,
  downloadSetting,
  archiveBotSetting,
  ehSetting,
  favoriteSetting,
  mouseSetting,
  myTagsSetting,
  networkSetting,
  performanceSetting,
  preferenceSetting,
  readSetting,
  securitySetting,
  siteSetting,
  styleSetting,
  superResolutionSetting,
  imageTranslationSetting,
  inferenceSetting,
  userSetting,
  keyboardShortcutSetting,
  builtInBlockedUserService,
];

void main(List<String> args) async {
  if (GetPlatform.isDesktop && runWebViewTitleBarWidget(args)) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  if (GetPlatform.isMacOS) {
    await WindowManipulator.initialize();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  lifeCircleBeans = topologicalSort(lifeCircleBeans);
  await _initBeansInParallel(lifeCircleBeans);

  runApp(const MyApp());
}

/// Initializes beans in dependency waves: beans whose declared
/// [JHLifeCircleBean.initDependencies] are all initialized run concurrently in
/// the same wave, while cross-wave ordering is preserved exactly as expressed
/// by the dependency graph (identical semantics to the previous serial loop).
Future<void> _initBeansInParallel(List<JHLifeCircleBean> sortedBeans) async {
  final Set<JHLifeCircleBean> remaining = sortedBeans.toSet();
  final Set<JHLifeCircleBean> initialized = <JHLifeCircleBean>{};

  while (remaining.isNotEmpty) {
    final List<JHLifeCircleBean> wave =
        remaining
            .where((bean) => bean.initDependencies.every(initialized.contains))
            .toList();

    // topologicalSort visits every dependency before its dependents, so a
    // ready wave always exists unless the graph has a cycle (which the sort
    // already rejects). Guard anyway to never deadlock on a graph mutation.
    if (wave.isEmpty) {
      for (final JHLifeCircleBean bean in remaining) {
        await bean.initBean();
        initialized.add(bean);
      }
      break;
    }

    remaining.removeAll(wave);
    await Future.wait(wave.map((bean) => bean.initBean()));
    initialized.addAll(wave);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget app = GetMaterialApp(
      title: 'JHenTai',
      themeMode: styleSetting.themeMode.value,
      theme: ThemeConfig.theme(
        styleSetting.lightThemeColor.value,
        Brightness.light,
      ),
      darkTheme: ThemeConfig.theme(
        styleSetting.darkThemeColor.value,
        Brightness.dark,
      ),

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
      initialRoute:
          securitySetting.enablePasswordAuth.isTrue ||
                  securitySetting.enableBiometricAuth.isTrue
              ? Routes.lock
              : Routes.home,
      navigatorObservers: [GetXRouterObserver()],
      builder: (context, child) => AppManager(child: child!),

      /// enable swipe back feature
      popGesture: preferenceSetting.enableSwipeBackGesture.isTrue,
      onReady: () {
        for (JHLifeCircleBean bean in lifeCircleBeans) {
          bean.afterBeanReady();
        }
      },
    );

    /// https://github.com/flutter/flutter/issues/182444
    if (Platform.isWindows) {
      app = ExcludeSemantics(child: app);
    }
    return app;
  }
}

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
