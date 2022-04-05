import 'package:flutter/material.dart';
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

class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /// use LayoutBuilder to listen to the screen resize
    return LayoutBuilder(
      builder: (context, constraints) => Obx(
        () {
          if (StyleSetting.enableTabletLayout.isFalse) {
            StyleSetting.currentEnableTabletLayout.value = false;
            return HomePage();
          }

          if (fullScreenWidth < 600) {
            StyleSetting.currentEnableTabletLayout.value = false;

            /// pop all pages in right screen if exists
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
      observers: [GetObserver(null, Get.routing)],
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
      observers: [GetObserver(null, Get.routing)],
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
