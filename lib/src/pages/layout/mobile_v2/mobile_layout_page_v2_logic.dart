import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../mixin/double_tap_to_refresh_logic_mixin.dart';

class MobileLayoutPageV2Logic extends GetxController with DoubleTapToRefreshLogicMixin {
  final String bodyId = 'bodyId';
  final String tabBarId = 'tabBarId';
  final String bottomNavigationBarId = 'bottomNavigationBarId';

  @override
  final MobileLayoutPageV2State state = MobileLayoutPageV2State();

  Worker? hideBottomBarLister;

  @override
  void onReady() {
    super.onReady();

    /// If user hideBottomBar, reset the selected navigation index to 0
    hideBottomBarLister = ever(StyleSetting.hideBottomBar, (_) {
      if (StyleSetting.hideBottomBar.isTrue) {
        handleTapNavigationBarButton(0);
      }
    });
  }

  @override
  void onClose() {
    super.onClose();
    hideBottomBarLister?.dispose();
  }

  void handleTapTabBarButton(int index) {
    if (state.icons[index].enterNewRoute) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
      toRoute(state.icons[index].routeName);
      return;
    }

    // make sure we are at the home tab
    handleTapNavigationBarButton(0);

    state.icons[index].shouldRender = true;

    int prevIndex = state.selectedDrawerTabIndex;
    state.selectedDrawerTabIndex = index;

    if (prevIndex != index) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
      update([bodyId]);
    }
  }

  void handleTapNavigationBarButton(int index) {
    if (index != state.selectedNavigationIndex) {
      state.selectedNavigationIndex = index;
      updateSafely([bodyId, bottomNavigationBarId]);
      return;
    }

    if (index == 0) {
      ScrollController? scrollController = state.icons[state.selectedDrawerTabIndex].scrollController?.call();
      handleTap2Scroll2Top(scrollController);
    }
  }
}
