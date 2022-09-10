import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:resizable_widget/resizable_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../routes/routes.dart';
import '../../../service/windows_service.dart';
import '../../blank_page.dart';
import '../../home_page.dart';

class TabletLayoutPageV2 extends StatefulWidget {
  const TabletLayoutPageV2({Key? key}) : super(key: key);

  @override
  State<TabletLayoutPageV2> createState() => _TabletLayoutPageV2State();
}

class _TabletLayoutPageV2State extends State<TabletLayoutPageV2> {
  final WindowService windowService = Get.find<WindowService>();

  double leftColumnWidthRatio = 1 - 0.618;

  @override
  void initState() {
    super.initState();
    leftColumnWidthRatio = windowService.leftColumnWidthRatio;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.behaviorWithoutScrollBar,
      child: ResizableWidget(
        separatorColor: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        separatorSize: 1.5,
        percentages: [leftColumnWidthRatio, 1 - leftColumnWidthRatio],
        onResized: windowService.handleResized,
        isDisabledSmartHide: true,
        children: [
          _leftColumn(),
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.black, width: 0.3))),
            child: _rightColumn(),
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
