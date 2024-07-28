import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../service/windows_service.dart';
import '../../../setting/preference_setting.dart';
import '../../blank_page.dart';
import '../../home_page.dart';

class TabletLayoutPageV2 extends StatefulWidget {
  const TabletLayoutPageV2({super.key});

  @override
  State<TabletLayoutPageV2> createState() => _TabletLayoutPageV2State();
}

class _TabletLayoutPageV2State extends State<TabletLayoutPageV2> {
  final ResizableController resizableController = ResizableController();

  @override
  void initState() {
    super.initState();

    resizableController.addListener(() {
      windowService.handleDoubleColumnResized(resizableController.ratios);
    });
  }

  @override
  void dispose() {
    super.dispose();

    resizableController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConfig.backGroundColor(context),
      body: ResizableContainer(
        direction: Axis.horizontal,
        controller: resizableController,
        children: [
          ResizableChild(
            child: _leftColumn(),
            size: ResizableSize.ratio(windowService.leftColumnWidthRatio),
            minSize: 100,
          ),
          ResizableChild(
            child: _rightColumn(),
            size: ResizableSize.ratio(1 - windowService.leftColumnWidthRatio),
            minSize: 100,
          ),
        ],
        divider: ResizableDivider(
          thickness: 1.5,
          size: 7.5,
          color: UIConfig.layoutDividerColor(context),
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return Navigator(
      key: Get.nestedKey(leftV2),

      /// make sure controller is destroyed automatically and route args is passed properly
      observers: [GetObserver(null, leftRouting)],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: const RouteSettings(name: Routes.mobileLayoutV2),
          page: MobileLayoutPageV2.new,
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

          popGesture: preferenceSetting.enableSwipeBackGesture.isTrue,
          transition: Routes.defaultTransition,
          transitionDuration: const Duration(milliseconds: 150),
        );
      },
    );
  }

  Widget _rightColumn() {
    return Navigator(
      key: Get.nestedKey(rightV2),
      observers: [GetObserver(null, rightRouting)],
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
