import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page.dart';
import 'package:jhentai/src/pages/layout/tablet_layout_page.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/windows_app.dart';

import '../consts/eh_consts.dart';
import '../routes/routes.dart';
import '../utils/route_util.dart';
import '../utils/screen_size_util.dart';
import '../utils/snack_util.dart';
import '../widget/app_state_listener.dart';
import 'layout/mobile/mobile_layout_page.dart';

const int left = 1;
const int right = 2;
const int fullScreen = 3;

Routing leftRouting = Routing();
Routing rightRouting = Routing();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastDetectedUrl;

  @override
  void initState() {
    super.initState();
    initToast(context);
    handleUrlInClipBoard();
    AppStateListener.registerDidChangeAppLifecycleStateCallback(resumeAndHandleUrlInClipBoard);
  }

  @override
  Widget build(BuildContext context) {
    return WindowsApp(
      /// Use LayoutBuilder to listen to resize of window.
      child: LayoutBuilder(
        builder: (context, constraints) => Obx(
          () {
            if (StyleSetting.layoutMode.value == LayoutMode.mobile) {
              StyleSetting.actualLayoutMode.value = LayoutMode.mobile;
              return MobileLayoutPage();
            }

            /// Device width is under 600, degrade to mobile layout.
            if (fullScreenWidth < 600) {
              StyleSetting.actualLayoutMode.value = LayoutMode.mobile;
              untilBlankPage();
              return MobileLayoutPage();
            }

            if (StyleSetting.layoutMode.value == LayoutMode.tablet) {
              StyleSetting.actualLayoutMode.value = LayoutMode.tablet;
              return const TabletLayoutPage();
            }

            StyleSetting.actualLayoutMode.value = LayoutMode.desktop;
            return DesktopLayoutPage();
          },
        ),
      ),
    );
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void resumeAndHandleUrlInClipBoard(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      handleUrlInClipBoard();
    }
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void handleUrlInClipBoard() async {
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
      onTap: (snackbar) {
        toNamed(
          Routes.details,
          arguments: text,
          offAllBefore: false,
          preventDuplicates: false,
        );
      },
      longDuration: true,
    );
  }
}
