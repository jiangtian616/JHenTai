import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../routes/routes.dart';
import '../../blank_page.dart';
import '../../home_page.dart';

class TabletLayoutPageV2 extends StatelessWidget {
  const TabletLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
        scrollbars: false,
      ),
      child: Row(
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
      ),
    );
  }

  Widget _leftColumn() {
    return Navigator(
      key: Get.nestedKey(leftV2),

      /// make sure controller is destroyed automatically and route args is passed properly
      observers: [GetObserver(null, leftRouting), SentryNavigatorObserver()],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: const RouteSettings(name: Routes.mobileLayoutV2),
          page: () => MobileLayoutPageV2(),
          popGesture: true,
          transition: Transition.fadeIn,
          showCupertinoParallax: false,
        ),
      ],
      onGenerateRoute: (settings) {
        Get.routing.args = settings.arguments;
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
      key: Get.nestedKey(rightV2),
      observers: [GetObserver(null, rightRouting), SentryNavigatorObserver()],
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
        Get.routing.args = settings.arguments;
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
