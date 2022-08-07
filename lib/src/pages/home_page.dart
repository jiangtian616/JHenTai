import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_logic.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:jhentai/src/pages/layout/tablet/tablet_layout_page.dart';
import 'package:jhentai/src/pages/layout/tablet_v2/tablet_layout_page_v2.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_logic.dart';
import 'package:jhentai/src/pages/watched/watched_page_logic.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/will_pop_interceptor.dart';
import 'package:jhentai/src/widget/windows_app.dart';

import '../consts/eh_consts.dart';
import '../model/jh_layout.dart';
import '../routes/routes.dart';
import '../utils/route_util.dart';
import '../utils/screen_size_util.dart';
import '../utils/snack_util.dart';
import '../widget/app_state_listener.dart';
import 'favorite/favorite_page_logic.dart';
import 'gallerys/simple/gallerys_page_logic.dart';
import 'history/history_page_logic.dart';
import 'layout/mobile/mobile_layout_page.dart';

const int left = 1;
const int right = 2;
const int fullScreen = 3;
const int leftV2 = 4;
const int rightV2 = 5;

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
    _initPageLogic();
    _handleUrlInClipBoard();
    AppStateListener.registerDidChangeAppLifecycleStateCallback(resumeAndHandleUrlInClipBoard);
  }

  @override
  Widget build(BuildContext context) {
    return WindowsApp(
      /// Use LayoutBuilder to listen to resize of window.
      child: WillPopInterceptor(
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

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void _handleUrlInClipBoard() async {
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
        toRoute(
          Routes.details,
          arguments: text,
          offAllBefore: false,
          preventDuplicates: false,
        );
      },
      longDuration: true,
    );
  }

  void _initPageLogic() {
    /// Mobile layout v2
    Get.lazyPut(() => DashboardPageLogic(), fenix: true);

    /// Desktop layout
    Get.lazyPut(() => GallerysPageLogic(), fenix: true);
    Get.lazyPut(() => DesktopSearchPageLogic(), fenix: true);

    /// Mobile layout v2 & Desktop layout
    Get.lazyPut(() => PopularPageLogic(), fenix: true);
    Get.lazyPut(() => RanklistPageLogic(), fenix: true);
    Get.lazyPut(() => FavoritePageLogic(), fenix: true);
    Get.lazyPut(() => WatchedPageLogic(), fenix: true);
    Get.lazyPut(() => HistoryPageLogic(), fenix: true);
  }
}
