import 'dart:async';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image_page_url.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/gallery_image/gallery_image_page_logic.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:jhentai/src/pages/layout/tablet_v2/tablet_layout_page_v2.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:window_manager/window_manager.dart';

import '../mixin/window_widget_mixin.dart';
import '../mixin/login_required_logic_mixin.dart';
import '../model/jh_layout.dart';
import '../routes/routes.dart';
import '../setting/advanced_setting.dart';
import '../utils/route_util.dart';
import '../utils/screen_size_util.dart';
import '../utils/snack_util.dart';

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

class _HomePageState extends State<HomePage> with LoginRequiredMixin, WindowListener, WindowWidgetMixin {
  StreamSubscription? _intentDataStreamSubscription;
  String? _lastDetectedText;

  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    initToast(context);
    _initSharingIntent();
    _handleUrlInClipBoard();

    _listener = AppLifecycleListener(onResume: _handleUrlInClipBoard);
  }

  @override
  void dispose() {
    super.dispose();
    _intentDataStreamSubscription?.cancel();
    _listener.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWindow(
      child: LayoutBuilder(
        builder: (_, __) => Obx(
          () {
            if (styleSetting.layout.value == LayoutMode.mobileV2 || styleSetting.layout.value == LayoutMode.mobile) {
              styleSetting.actualLayout = LayoutMode.mobileV2;
              return MobileLayoutPageV2();
            }

            /// Device width is under 600, degrade to mobileV2 layout.
            if (fullScreenWidth < 600) {
              styleSetting.actualLayout = LayoutMode.mobileV2;
              untilRoute2BlankPage();
              return MobileLayoutPageV2();
            }

            if (styleSetting.layout.value == LayoutMode.tabletV2 || styleSetting.layout.value == LayoutMode.tablet) {
              styleSetting.actualLayout = LayoutMode.tabletV2;
              return TabletLayoutPageV2();
            }

            styleSetting.actualLayout = LayoutMode.desktop;
            return DesktopLayoutPage();
          },
        ),
      ),
    );
  }

  /// Listen to share or open urls/text coming from outside the app while the app is in the memory or is closed
  void _initSharingIntent() {
    if (!GetPlatform.isAndroid) {
      return;
    }

    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> files) {
        if (files.isEmpty) {
          return;
        }

        SharedMediaFile file = files.first;
        if (file.type != SharedMediaType.url && file.type != SharedMediaType.text) {
          return;
        }

        GalleryUrl? galleryUrl = GalleryUrl.tryParse(file.path);
        if (galleryUrl != null) {
          toRoute(
            Routes.details,
            arguments: DetailsPageArgument(galleryUrl: galleryUrl),
            offAllBefore: false,
            preventDuplicates: false,
          );
          return;
        }

        GalleryImagePageUrl? galleryImagePageUrl = GalleryImagePageUrl.tryParse(file.path);
        if (galleryImagePageUrl != null) {
          toRoute(
            Routes.imagePage,
            arguments: GalleryImagePageArgument(galleryImagePageUrl: galleryImagePageUrl),
            offAllBefore: false,
          );
          return;
        }

        toast('Invalid jump link', isShort: false);
      },
    ).whenComplete(() {
      ReceiveSharingIntent.instance.reset();
    });

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isEmpty) {
          return;
        }

        SharedMediaFile file = files.first;
        if (file.type != SharedMediaType.url && file.type != SharedMediaType.text) {
          return;
        }

        GalleryUrl? galleryUrl = GalleryUrl.tryParse(file.path);
        if (galleryUrl != null) {
          untilRoute(currentRoute: Routes.details, predicate: (route) => route.settings.name != Routes.read);
          toRoute(
            Routes.details,
            arguments: DetailsPageArgument(galleryUrl: galleryUrl),
            offAllBefore: false,
            preventDuplicates: false,
          );
          return;
        }

        GalleryImagePageUrl? galleryImagePageUrl = GalleryImagePageUrl.tryParse(file.path);
        if (galleryImagePageUrl != null) {
          untilRoute(currentRoute: Routes.details, predicate: (route) => route.settings.name != Routes.read);
          toRoute(
            Routes.imagePage,
            arguments: GalleryImagePageArgument(galleryImagePageUrl: galleryImagePageUrl),
            offAllBefore: false,
          );
          return;
        }
      },
      onError: (e) {
        log.error('ReceiveSharingIntent Error!', e);
        log.uploadError(e);
      },
    );
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void _handleUrlInClipBoard() async {
    if (advancedSetting.enableCheckClipboard.isFalse) {
      return;
    }

    String rawText = await FlutterClipboard.paste();
    GalleryUrl? galleryUrl = GalleryUrl.tryParse(rawText);
    GalleryImagePageUrl? galleryImagePageUrl = GalleryImagePageUrl.tryParse(rawText);

    if (galleryUrl == null && galleryImagePageUrl == null) {
      return;
    }

    /// show snack only once
    if (rawText == _lastDetectedText) {
      return;
    }

    _lastDetectedText = rawText;
    if (galleryUrl != null) {
      snack(
        'galleryUrlDetected'.tr,
        '${'galleryUrlDetectedHint'.tr}: ${galleryUrl.url}',
        onPressed: () {
          if (!galleryUrl.isEH && !userSetting.hasLoggedIn()) {
            showLoginToast();
            return;
          }
          toRoute(
            Routes.details,
            arguments: DetailsPageArgument(galleryUrl: galleryUrl),
            offAllBefore: false,
            preventDuplicates: false,
          );
        },
        isShort: true,
      );
    } else if (galleryImagePageUrl != null) {
      snack(
        'galleryUrlDetected'.tr,
        '${'galleryUrlDetectedHint'.tr}: ${galleryImagePageUrl.url}',
        onPressed: () {
          if (!galleryImagePageUrl.isEH && !userSetting.hasLoggedIn()) {
            showLoginToast();
            return;
          }
          toRoute(
            Routes.imagePage,
            arguments: GalleryImagePageArgument(galleryImagePageUrl: galleryImagePageUrl),
            offAllBefore: false,
          );
        },
        isShort: true,
      );
    }
  }
}
