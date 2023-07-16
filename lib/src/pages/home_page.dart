import 'dart:async';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:jhentai/src/pages/layout/tablet_v2/tablet_layout_page_v2.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/utils/version_util.dart';
import 'package:jhentai/src/widget/will_pop_interceptor.dart';
import 'package:jhentai/src/widget/window_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:retry/retry.dart';

import '../consts/eh_consts.dart';
import '../mixin/login_required_logic_mixin.dart';
import '../model/jh_layout.dart';
import '../network/eh_request.dart';
import '../routes/routes.dart';
import '../service/storage_service.dart';
import '../service/windows_service.dart';
import '../setting/advanced_setting.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/route_util.dart';
import '../utils/screen_size_util.dart';
import '../utils/snack_util.dart';
import '../utils/string_uril.dart';
import '../widget/app_manager.dart';
import '../widget/update_dialog.dart';

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

class _HomePageState extends State<HomePage> with LoginRequiredMixin {
  final StorageService storageService = Get.find();
  final WindowService windowService = Get.find<WindowService>();

  StreamSubscription? _intentDataStreamSubscription;
  String? _lastDetectedUrl;

  @override
  void initState() {
    super.initState();
    initToast(context);
    _initSharingIntent();
    _checkUpdate();
    _handleUrlInClipBoard();

    AppManager.registerDidChangeAppLifecycleStateCallback(resumeAndHandleUrlInClipBoard);
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
              windowService.handleWindowResized();

              if (StyleSetting.layout.value == LayoutMode.mobileV2 || StyleSetting.layout.value == LayoutMode.mobile) {
                StyleSetting.actualLayout = LayoutMode.mobileV2;
                return MobileLayoutPageV2();
              }

              /// Device width is under 600, degrade to mobileV2 layout.
              if (fullScreenWidth < 600) {
                StyleSetting.actualLayout = LayoutMode.mobileV2;
                untilRoute2BlankPage();
                return MobileLayoutPageV2();
              }

              if (StyleSetting.layout.value == LayoutMode.tabletV2 || StyleSetting.layout.value == LayoutMode.tablet) {
                StyleSetting.actualLayout = LayoutMode.tabletV2;
                return TabletLayoutPageV2();
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

    if (compareVersion(currentVersion, latestVersion) >= 0) {
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
        if (isEmptyOrNull(url)) {
          return;
        }

        Match? match = RegExp(r'https://e[-x]hentai\.org/g/\S+').firstMatch(url!);
        if (match == null) {
          toast('Invalid jump link', isShort: false);
        } else {
          toRoute(
            Routes.details,
            arguments: {'gid': parseGalleryUrl2Gid(url), 'galleryUrl': url},
            offAllBefore: false,
            preventDuplicates: false,
          );
        }
      },
    );

    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen(
      (String url) {
        Match? match = RegExp(r'https://e[-x]hentai\.org/g/\S+').firstMatch(url);
        if (match == null) {
          toast('Invalid jump link', isShort: false);
        } else {
          toRoute(
            Routes.details,
            arguments: {'gid': parseGalleryUrl2Gid(url), 'galleryUrl': url},
            offAllBefore: false,
            preventDuplicates: false,
          );
        }
      },
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

    Match? match = RegExp(r'https://e[-x]hentai\.org/g/\S+').firstMatch(await FlutterClipboard.paste());
    if (match == null) {
      return;
    }

    String url = match.group(0)!;

    /// show snack only once
    if (url == _lastDetectedUrl) {
      return;
    }

    _lastDetectedUrl = url;

    snack(
      'galleryUrlDetected'.tr,
      '${'galleryUrlDetectedHint'.tr}: $url',
      onPressed: () {
        if (url.startsWith('${EHConsts.EXIndex}/g') && !UserSetting.hasLoggedIn()) {
          showLoginToast();
          return;
        }
        toRoute(
          Routes.details,
          arguments: {'gid': parseGalleryUrl2Gid(url), 'galleryUrl': url},
          offAllBefore: false,
          preventDuplicates: false,
        );
      },
      longDuration: true,
    );
  }
}
