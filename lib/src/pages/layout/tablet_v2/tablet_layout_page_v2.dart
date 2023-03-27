import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import 'package:resizable_widget/resizable_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../service/windows_service.dart';
import '../../../setting/preference_setting.dart';
import '../../../widget/eh_separator.dart';
import '../../blank_page.dart';
import '../../home_page.dart';

class TabletLayoutPageV2 extends StatelessWidget {
  final WindowService windowService = Get.find<WindowService>();

  TabletLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UIConfig.backGroundColor(context),
      child: ResizableWidget(
        key: Key(UIConfig.backGroundColor(context).hashCode.toString()),
        separatorSize: 7.5,
        separatorColor: UIConfig.layoutDividerColor(context),
        separatorBuilder: (SeparatorArgsInfo info, SeparatorController controller) => EHSeparator(info: info, controller: controller),
        percentages: [windowService.leftColumnWidthRatio, 1 - windowService.leftColumnWidthRatio],
        onResized: windowService.handleColumnResized,
        isDisabledSmartHide: true,
        children: [_leftColumn(), _rightColumn()],
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

          popGesture: PreferenceSetting.enableSwipeBackGesture.isTrue,
          transition: Routes.defaultTransition,
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
