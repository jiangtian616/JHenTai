import 'package:flutter/cupertino.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/windows_service.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../mixin/double_tap_to_refresh_logic_mixin.dart';
import '../../home_page.dart';
import 'desktop_layout_page_state.dart';

class DesktopLayoutPageLogic extends GetxController with DoubleTapToRefreshLogicMixin {
  final String tabBarId = 'tabBarId';
  final String leftColumnId = 'leftColumnId';

  @override
  DesktopLayoutPageState state = DesktopLayoutPageState();

  final ResizableController resizableController = ResizableController();

  @override
  void onInit() {
    super.onInit();

    resizableController.addListener(() {
      windowService.handleDoubleColumnResized(resizableController.ratios);
    });
  }

  @override
  void onClose() {
    super.onClose();

    resizableController.dispose();
  }

  void updateHoveringTabIndex(int? index) {
    state.hoveringTabIndex = index;
    update([tabBarId]);
  }

  /// tap another bar -> change index
  /// at gallery bar and tap gallery bar again -> scroll to top
  /// at gallery bar and tap gallery bar twice -> scroll to top and refresh
  void handleTapTabBarButton(int index) {
    state.icons[index].shouldRender = true;

    int prevIndex = state.selectedTabIndex;
    state.selectedTabIndex = index;

    if (!isRouteAtTop(Routes.desktopHome)) {
      untilRoute2DesktopHomePage();
    }

    if (prevIndex != index) {
      leftRouting.args = null;
      Get.parameters = {};
      update([tabBarId, leftColumnId]);
      return;
    }

    ScrollController? scrollController = state.icons[index].scrollController?.call();
    handleTap2Scroll2Top(scrollController);
  }
}
