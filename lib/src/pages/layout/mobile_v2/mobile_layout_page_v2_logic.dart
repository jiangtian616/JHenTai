import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/utils/route_util.dart';

class MobileLayoutPageV2Logic extends GetxController {
  final String tabBarId = 'tabBarId';
  final String pageId = 'pageId';

  final MobileLayoutPageV2State state = MobileLayoutPageV2State();

  void handleTapTabBarButton(int index) {
    if (state.icons[index].enterNewRoute) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
      toRoute(state.icons[index].routeName);
      return;
    }

    state.icons[index].shouldRender = true;

    int prevIndex = state.selectedTabIndex;
    state.selectedTabIndex = index;

    if (prevIndex != index) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
      update([pageId]);
    }
  }
}
