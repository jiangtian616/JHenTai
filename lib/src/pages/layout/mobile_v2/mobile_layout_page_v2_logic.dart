import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../mixin/double_tap_to_refresh_logic_mixin.dart';
import '../../../setting/preference_setting.dart';

class MobileLayoutPageV2Logic extends GetxController with DoubleTapToRefreshLogicMixin {
  final String bodyId = 'bodyId';
  final String tabBarId = 'tabBarId';
  final String bottomNavigationBarId = 'bottomNavigationBarId';

  @override
  final MobileLayoutPageV2State state = MobileLayoutPageV2State();

  Worker? hideBottomBarLister;
  Worker? simpleModeLister;

  @override
  void onReady() {
    super.onReady();

    /// If user hideBottomBar, reset the selected navigation index to 0
    hideBottomBarLister = ever(preferenceSetting.hideBottomBar, (_) {
      if (preferenceSetting.effectiveHideBottomBar) {
        handleTapNavigationBarButton(0);
      }
    });

    simpleModeLister = ever(preferenceSetting.simpleDashboardMode, (_) {
      update([bodyId]);
    });
  }

  @override
  void onClose() {
    super.onClose();
    hideBottomBarLister?.dispose();
    state.scrollController.dispose();
  }

  void handleTapTabBarButton(int index) {
    if (state.icons[index].enterNewRoute) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
      toRoute(state.icons[index].routeName);
      return;
    }

    final bool navigationChanged = state.selectedNavigationIndex != 0;
    final int previousIndex = state.selectedDrawerTabIndex;
    final bool drawerTabChanged = previousIndex != index;

    // Make sure we are at the home tab before selecting a page from the
    // sidebar. Apply all state changes before issuing one GetX update so the
    // body never rebuilds with only half of the navigation state changed.
    if (navigationChanged) {
      state.selectedNavigationIndex = 0;
    }

    state.icons[index].shouldRender = true;
    state.selectedDrawerTabIndex = index;

    if (drawerTabChanged) {
      MobileLayoutPageV2State.scaffoldKey.currentState?.closeDrawer();
    }

    if (navigationChanged || drawerTabChanged) {
      final List<Object> updateIds = [bodyId];
      if (navigationChanged) {
        updateIds.add(bottomNavigationBarId);
      }
      if (drawerTabChanged) {
        updateIds.add(tabBarId);
      }
      updateSafely(updateIds);
    }
  }

  void handleTapTabBarButtonByRouteName(String routeName) {
    int? index = state.icons.firstIndexWhereOrNull((icon) => icon.routeName == routeName);
    if (index == null) {
      return;
    }

    handleTapTabBarButton(index);
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
