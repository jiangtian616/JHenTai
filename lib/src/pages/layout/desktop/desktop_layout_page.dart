import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_state.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../config/global_config.dart';
import '../../../routes/routes.dart';
import '../../blank_page.dart';
import 'desktop_layout_page_logic.dart';

class DesktopLayoutPage extends StatelessWidget {
  final DesktopLayoutPageLogic logic = Get.put(DesktopLayoutPageLogic());
  final DesktopLayoutPageState state = Get.find<DesktopLayoutPageLogic>().state;

  DesktopLayoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _leftTabBar(context),
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

  Widget _leftTabBar(BuildContext context) {
    return Material(
      child: Container(
        width: GlobalConfig.desktopLeftTabBarWidth,
        decoration: BoxDecoration(
          color: Theme.of(context).appBarTheme.backgroundColor,
          border: const Border(right: BorderSide(color: Colors.black, width: 0.3)),
        ),
        child: GetBuilder<DesktopLayoutPageLogic>(
          id: logic.tabBarId,
          builder: (_) => ListView.builder(
            itemCount: state.icons.length,
            itemExtent: 64,
            itemBuilder: (_, int index) => MouseRegion(
              onEnter: (_) {
                state.hoverTabIndex = index;
                logic.update([logic.tabBarId]);
              },
              onExit: (_) {
                state.hoverTabIndex = null;
                logic.update([logic.tabBarId]);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: state.selectedTabIndex == index ? state.icons[index].selectedIcon : state.icons[index].unselectedIcon,
                    onPressed: () {
                      state.selectedTabIndex = index;
                      logic.update([logic.tabBarId, logic.pageId]);
                    },
                  ),
                  if (state.hoverTabIndex == index)
                    FadeIn(
                      child: Text(state.icons[index].name.tr, style: const TextStyle(fontSize: 12)),
                      duration: const Duration(milliseconds: 200),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return GetBuilder<DesktopLayoutPageLogic>(
      id: logic.pageId,
      builder: (_) => state.icons[state.selectedTabIndex].page,
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
