import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_state.dart';
import 'package:jhentai/src/widget/eh_separator.dart';
import 'package:resizable_widget/resizable_widget.dart';
import 'package:jhentai/src/widget/focus_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../blank_page.dart';
import 'desktop_layout_page_logic.dart';

class DesktopLayoutPage extends StatelessWidget {
  final DesktopLayoutPageLogic logic = Get.put(DesktopLayoutPageLogic(), permanent: true);
  final DesktopLayoutPageState state = Get.find<DesktopLayoutPageLogic>().state;

  DesktopLayoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.behaviorWithScrollBar,
      child: Row(
        children: [
          _leftTabBar(context),
          Expanded(
            child: ResizableWidget(
              separatorColor: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
              separatorSize: GetPlatform.isWindows ? 7.5 : 1.5,
              separatorBuilder: (SeparatorArgsInfo info, SeparatorController controller) =>
                  GetPlatform.isWindows ? EHSeparator(info: info, controller: controller) : DefaultSeparator(info: info, controller: controller),
              percentages: [state.leftColumnWidthRatio, 1 - state.leftColumnWidthRatio],
              onResized: logic.windowService.handleResized,
              isDisabledSmartHide: true,
              children: [
                _leftColumn(),
                _rightColumn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftTabBar(BuildContext context) {
    return Material(
      child: Container(
        width: UIConfig.desktopLeftTabBarWidth,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          border: Border(right: BorderSide(color: Get.theme.colorScheme.onBackground, width: 0.3)),
        ),
        child: FocusScope(
          autofocus: true,
          node: state.leftTabBarFocusScopeNode,
          child: GetBuilder<DesktopLayoutPageLogic>(
            id: logic.tabBarId,
            builder: (_) => ListView.builder(
              itemCount: state.icons.length,
              itemExtent: UIConfig.desktopLeftTabBarItemHeight,
              itemBuilder: (_, int index) => MouseRegion(
                onEnter: (_) {
                  state.hoveredTabIndex = index;
                  logic.update([logic.tabBarId]);
                },
                onExit: (_) {
                  state.hoveredTabIndex = null;
                  logic.update([logic.tabBarId]);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: FocusWidget(
                        enableFocus: state.icons[index].routeName != Routes.setting,
                        focusedDecoration: const BoxDecoration(color: Colors.grey),
                        handleTapEnter: () => logic.handleTapTabBarButton(index),
                        handleTapArrowRight: () {
                          if (state.selectedTabIndex != index) {
                            logic.handleTapTabBarButton(index);
                          } else {
                            state.leftColumnFocusScopeNode.requestFocus();
                          }
                        },
                        child: ExcludeFocus(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: state.selectedTabIndex == index
                                    ? Border(left: BorderSide(width: 4, color: Get.theme.colorScheme.onBackground))
                                    : null,
                              ),
                              child: IconButton(
                                onPressed: () => logic.handleTapTabBarButton(index),
                                icon: state.selectedTabIndex == index ? state.icons[index].selectedIcon : state.icons[index].unselectedIcon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: UIConfig.desktopLeftTabBarTextHeight,
                      child: state.hoveredTabIndex != index
                          ? null
                          : FadeIn(
                              child: Text(state.icons[index].name.tr, style: const TextStyle(fontSize: 12)),
                              duration: const Duration(milliseconds: 200),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return FocusScope(
      node: state.leftColumnFocusScopeNode,
      child: GetBuilder<DesktopLayoutPageLogic>(
        id: logic.leftColumnId,
        builder: (_) => Stack(
          children: state.icons
              .where((icon) => icon.shouldRender)
              .mapIndexed((index, icon) => Offstage(
                    offstage: state.selectedTabOrder != index,
                    child: icon.page.call(),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _rightColumn() {
    return Navigator(
      key: Get.nestedKey(right),
      requestFocus: false,
      observers: [GetObserver(null, rightRouting), SentryNavigatorObserver(), _FocusObserver()],
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

class _FocusObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    Get.find<DesktopLayoutPageLogic>().state.leftColumnFocusScopeNode.requestFocus();
    super.didPush(route, previousRoute);
  }
}
