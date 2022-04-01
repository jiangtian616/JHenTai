import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/home_page_logic.dart';
import 'package:jhentai/src/pages/home/home_page.dart';
import 'package:jhentai/src/pages/home/home_page_state.dart';
import 'package:jhentai/src/pages/setting/about/setting_about_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

const int left = 1;
const int right = 2;

class StartPage extends StatelessWidget {
  StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (StyleSetting.enableTabletLayout.isFalse) {
        return HomePage();
      }

      /// tablet layout
      return Row(
        children: [
          Expanded(
            child: Navigator(
              key: Get.nestedKey(left),
              /// make sure controller is destroyed automatically and route args is passed properly
              observers: [GetObserver(null, Get.routing)],
              onGenerateInitialRoutes: (_, __) => [
                GetPageRoute(
                  settings: const RouteSettings(name: Routes.home),
                  page: () => HomePage(),
                ),
              ],
              onGenerateRoute: (settings) {
                return GetPageRoute(
                  settings: settings,
                  page: Routes.pages.firstWhere((page) => page.name == settings.name).page,

                  /// do not use swipe back in tablet layout!
                  popGesture: false,
                  transition: Transition.fadeIn,
                );
              },
            ),
          ),
          Expanded(
            child: Navigator(
              key: Get.nestedKey(right),
              observers: [GetObserver(null, Get.routing)],
              onGenerateInitialRoutes: (_, __) => [
                GetPageRoute(
                  settings: const RouteSettings(name: Routes.settingAbout),
                  page: () => SettingAboutPage(),
                ),
              ],
              onGenerateRoute: (settings) {
                return GetPageRoute(
                  settings: settings,
                  page: Routes.pages.firstWhere((page) => page.name == settings.name).page,

                  /// do not use swipe back in tablet layout!
                  popGesture: false,
                  transition: Transition.fadeIn,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
