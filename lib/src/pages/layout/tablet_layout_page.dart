import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../routes/routes.dart';
import '../blank_page.dart';
import 'mobile/mobile_layout_page.dart';

class TabletLayoutPage extends StatelessWidget {
  const TabletLayoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _leftColumn()),
        Expanded(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.black, width: 0.3))),
            child: _rightColumn(),
          ),
        ),
      ],
    );
  }

  Widget _leftColumn() {
    return Navigator(
      key: Get.nestedKey(left),

      /// make sure controller is destroyed automatically and route args is passed properly
      observers: [GetObserver((routing) => leftRouting = routing!, Get.routing), SentryNavigatorObserver()],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: const RouteSettings(name: Routes.mobileLayout),
          page: () => MobileLayoutPage(),
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

  Widget _rightColumn() {
    return Navigator(
      key: Get.nestedKey(right),
      observers: [GetObserver((routing) => rightRouting = routing!, Get.routing), SentryNavigatorObserver()],
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
