import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/blank_page.dart';
import 'package:jhentai/src/pages/home/home_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../utils/route_util.dart';
import '../utils/size_util.dart';

const int left = 1;
const int right = 2;
const int fullScreen = 3;

late Routing leftRouting;
late Routing rightRouting;

class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppListener(
      child: Obx(
        () {
          if (StyleSetting.enableTabletLayout.isFalse) {
            StyleSetting.currentEnableTabletLayout.value = false;
            return HomePage();
          }

          if (fullScreenWidth < 600) {
            StyleSetting.currentEnableTabletLayout.value = false;
            untilBlankPage();
            return HomePage();
          }

          StyleSetting.currentEnableTabletLayout.value = true;

          /// tablet layout
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _leftScreen()),
                    Container(width: 0.3, color: Colors.black),
                  ],
                ),
              ),
              Expanded(child: _rightScreen()),
            ],
          );
        },
      ),
    );
  }

  Widget _leftScreen() {
    return Navigator(
      key: Get.nestedKey(left),

      /// make sure controller is destroyed automatically and route args is passed properly
      observers: [GetObserver((routing) => leftRouting = routing!, Get.routing)],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: const RouteSettings(name: Routes.home),
          page: () => HomePage(),
          popGesture: true,
          transition: Transition.fadeIn,
          showCupertinoParallax: false,
        ),
      ],
      onGenerateRoute: (settings) {
        Get.parameters = Get.routeTree.matchRoute(settings.name!).parameters;

        return GetPageRoute(
          settings: settings,

          /// setting name may include path params
          page: Routes.pages.firstWhere((page) => settings.name!.split('?')[0] == page.name).page,

          popGesture: true,
          transition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 150),
        );
      },
    );
  }

  Widget _rightScreen() {
    return Navigator(
      key: Get.nestedKey(right),
      observers: [GetObserver((routing) => rightRouting = routing!, Get.routing)],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: const RouteSettings(name: Routes.blank),
          page: () => const BlankPage(),
          popGesture: false,
          transition: Transition.fadeIn,
          showCupertinoParallax: false,
        ),
      ],
      onGenerateRoute: (settings) {
        Get.parameters = Get.routeTree.matchRoute(settings.name!).parameters;
        return GetPageRoute(
          settings: settings,

          /// setting name may include path params
          page: Routes.pages.firstWhere((page) => settings.name!.split('?')[0] == page.name).page,

          /// do not use swipe back in tablet layout!
          popGesture: false,
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 150),
          showCupertinoParallax: false,
        );
      },
    );
  }
}

class AppListener extends StatefulWidget {
  final Widget child;

  const AppListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AppListener> createState() => _AppListenerState();
}

class _AppListenerState extends State<AppListener> with WidgetsBindingObserver {
  AppLifecycleState state = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    Get.changeThemeMode(
      WidgetsBinding.instance?.window.platformBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    );
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
    /// so i choose to set FLAG_SECURE to do the same effect.
    if (state == AppLifecycleState.inactive) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        setState(() {
          this.state = state;
        });
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        setState(() {
          this.state = state;
        });
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isAndroid || state == AppLifecycleState.resumed) {
      /// use LayoutBuilder to listen to the screen resize
      return LayoutBuilder(
        builder: (context, constraints) => widget.child,
      );
    }

    return Blur(
      child: LayoutBuilder(
        builder: (context, constraints) => widget.child,
      ),
    );
  }
}
