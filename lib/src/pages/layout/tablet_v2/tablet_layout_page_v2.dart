import 'package:flutter/material.dart';
import 'dart:collection';

import '../../../utils/adaptive_pane_navigation.dart';
import '../../../widget/adaptive_split_view.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:jhentai/src/widget/will_pop_interceptor.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../service/windows_service.dart';
import '../../../setting/preference_setting.dart';
import '../../blank_page.dart';
import '../../home_page.dart';

class TabletLayoutPageV2 extends StatefulWidget {
  final bool compact;
  const TabletLayoutPageV2({super.key, this.compact = false});

  @override
  State<TabletLayoutPageV2> createState() => _TabletLayoutPageV2State();
}

class _TabletLayoutPageV2State extends State<TabletLayoutPageV2> {
  late final NavigatorObserver _leftObserver;
  late final NavigatorObserver _rightObserver;

  @override
  void initState() {
    super.initState();
    adaptivePaneNavigation.attach();
    _leftObserver = adaptivePaneNavigation.observer(AdaptivePane.left);
    _rightObserver = adaptivePaneNavigation.observer(AdaptivePane.right);
  }

  @override
  void dispose() {
    adaptivePaneNavigation.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    adaptivePaneNavigation.compact = widget.compact;
    return WillPopInterceptor(
      child: Scaffold(
        backgroundColor: UIConfig.backGroundColor(context),
        body: AnimatedBuilder(
          animation: adaptivePaneNavigation,
          builder: (context, _) => AdaptiveSplitView(
            compact: widget.compact,
            showRight: adaptivePaneNavigation.activePane == AdaptivePane.right,
            initialRatio: windowService.leftColumnWidthRatio,
            onRatioChanged: (ratio) => windowService.handleDoubleColumnResized(UnmodifiableListView([ratio, 1 - ratio])),
            dividerColor: UIConfig.layoutDividerColor(context),
            left: Listener(
              onPointerDown: (_) => adaptivePaneNavigation.focus(AdaptivePane.left),
              child: MediaQuery.removePadding(
                context: context,
                removeRight: !widget.compact,
                child: _leftColumn(),
              ),
            ),
            right: Listener(
              onPointerDown: (_) => adaptivePaneNavigation.focus(AdaptivePane.right),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: !widget.compact,
                child: _rightColumn(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return Navigator(
      key: Get.nestedKey(leftV2),

      /// make sure controller is destroyed automatically and route args is passed properly
      observers: [GetObserver(null, leftRouting), _leftObserver],
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
          transitionDuration: UIConfig.defaultPageRouteTransitionDuration,
        );
      },
    );
  }

  Widget _rightColumn() {
    return Navigator(
      key: Get.nestedKey(rightV2),
      observers: [GetObserver(null, rightRouting), _rightObserver],
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

          // New compact routes can use the user's normal phone back gesture.
          popGesture: widget.compact && preferenceSetting.enableSwipeBackGesture.isTrue,
          transition: Transition.fadeIn,
          transitionDuration: UIConfig.defaultPageRouteTransitionDuration,
          showCupertinoParallax: false,
        );
      },
    );
  }
}
