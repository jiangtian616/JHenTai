import 'dart:async';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:jhentai/src/pages/layout/tablet/tablet_layout_page.dart';
import 'package:jhentai/src/pages/layout/tablet_v2/tablet_layout_page_v2.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/will_pop_interceptor.dart';
import 'package:jhentai/src/widget/window_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:retry/retry.dart';

import '../consts/eh_consts.dart';
import '../model/jh_layout.dart';
import '../network/eh_request.dart';
import '../routes/routes.dart';
import '../service/storage_service.dart';
import '../setting/advanced_setting.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/route_util.dart';
import '../utils/screen_size_util.dart';
import '../utils/snack_util.dart';
import '../widget/app_state_listener.dart';
import '../widget/update_dialog.dart';
import 'layout/mobile/mobile_layout_page.dart';

const int left = 1;
const int right = 2;
const int fullScreen = 3;
const int leftV2 = 4;
const int rightV2 = 5;

Routing leftRouting = Routing();
Routing rightRouting = Routing();

/// Core widget to decide which layout to be applied
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService storageService = Get.find();

  StreamSubscription? _intentDataStreamSubscription;
  String? _lastDetectedUrl;

  @override
  void initState() {
    super.initState();
    initToast(context);
    _initSharingIntent();
    _checkUpdate();
    _handleUrlInClipBoard();

    AppStateListener.registerDidChangeAppLifecycleStateCallback(resumeAndHandleUrlInClipBoard);
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WindowWidget(
      child: WillPopInterceptor(
        /// Use LayoutBuilder to listen to resize of window.
        child: LayoutBuilder(
          builder: (_, __) => Obx(
            () {
              if (StyleSetting.layout.value == LayoutMode.mobileV2) {
                StyleSetting.actualLayout = LayoutMode.mobileV2;
                return MobileLayoutPageV2();
              }

              if (StyleSetting.layout.value == LayoutMode.mobile) {
                StyleSetting.actualLayout = LayoutMode.mobile;
                return MobileLayoutPage();
              }

              /// Device width is under 600, degrade to mobile layout.
              if (fullScreenWidth < 600) {
                StyleSetting.actualLayout = StyleSetting.layout.value == LayoutMode.tablet ? LayoutMode.mobile : LayoutMode.mobileV2;
                untilRoute2BlankPage();
                return StyleSetting.layout.value == LayoutMode.tablet ? MobileLayoutPage() : MobileLayoutPageV2();
              }

              if (StyleSetting.layout.value == LayoutMode.tablet) {
                StyleSetting.actualLayout = LayoutMode.tablet;
                return const TabletLayoutPage();
              }

              if (StyleSetting.layout.value == LayoutMode.tabletV2) {
                StyleSetting.actualLayout = LayoutMode.tabletV2;
                return const TabletLayoutPageV2();
              }

              StyleSetting.actualLayout = LayoutMode.desktop;
              return DesktopLayoutPage();
            },
          ),
        ),
      ),
    );
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void resumeAndHandleUrlInClipBoard(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleUrlInClipBoard();
    }
  }

  Future<void> _checkUpdate() async {
    if (AdvancedSetting.enableCheckUpdate.isFalse) {
      return;
    }

    String url = 'https://api.github.com/repos/jiangtian616/JHenTai/releases';
    String latestVersion;

    try {
      latestVersion = (await retry(
        () => EHRequest.request(
          url: url,
          useCacheIfAvailable: false,
          parser: EHSpiderParser.githubReleasePage2LatestVersion,
        ),
        maxAttempts: 3,
      ))
          .trim()
          .split('+')[0];
    } on Exception catch (_) {
      Log.info('check update failed');
      return;
    }

    String? dismissVersion = storageService.read(UpdateDialog.dismissVersion);
    if (dismissVersion == latestVersion) {
      return;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = 'v${packageInfo.version}'.trim();
    Log.info('Latest version:[$latestVersion], current version: [$currentVersion]');

    if (latestVersion == currentVersion) {
      return;
    }

    Get.engine.addPostFrameCallback((_) {
      Get.dialog(UpdateDialog(currentVersion: currentVersion, latestVersion: latestVersion));
    });
  }

  /// Listen to share or open urls/text coming from outside the app while the app is in the memory or is closed
  void _initSharingIntent() {
    if (!GetPlatform.isAndroid) {
      return;
    }

    ReceiveSharingIntent.getInitialText().then(
      (String? url) {
        if (url != null) {
          toRoute(
            Routes.details,
            arguments: {'galleryUrl': url},
            offAllBefore: false,
            preventDuplicates: false,
          );
        }
      },
    );

    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen(
      (String url) => toRoute(
        Routes.details,
        arguments: {'galleryUrl': url},
        offAllBefore: false,
        preventDuplicates: false,
      ),
      onError: (e) {
        Log.error('ReceiveSharingIntent Error!', e);
        Log.upload(e);
      },
    );
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void _handleUrlInClipBoard() async {
    if (AdvancedSetting.enableCheckClipboard.isFalse) {
      return;
    }

    String text = await FlutterClipboard.paste();
    if (!text.startsWith('${EHConsts.EHIndex}/g') && !text.startsWith('${EHConsts.EXIndex}/g')) {
      return;
    }

    /// show snack only once
    if (text == _lastDetectedUrl) {
      return;
    }

    _lastDetectedUrl = text;

    snack(
      'galleryUrlDetected'.tr,
      '${'galleryUrlDetectedHint'.tr}: $text',
      onTap: (_) {
        toRoute(
          Routes.details,
          arguments: {'galleryUrl': text},
          offAllBefore: false,
          preventDuplicates: false,
        );
      },
      longDuration: true,
    );
  }
}
