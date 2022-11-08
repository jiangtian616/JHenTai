import 'package:flutter/cupertino.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../config/ui_config.dart';
import 'double_tap_to_refresh_state_mixin.dart';

mixin DoubleTapToRefreshLogicMixin on GetxController {
  DoubleTapToRefreshStateMixin get state;

  void handleTap2Scroll2Top(ScrollController? scrollController) {
    if ((scrollController?.hasClients ?? false) == false) {
      return;
    }

    /// scroll to top
    if (scrollController?.offset != 0) {
      scrollController?.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }

    if (state.lastTapTime == null) {
      state.lastTapTime = DateTime.now();
      return;
    }

    if (DateTime.now().difference(state.lastTapTime!).inMilliseconds <= 200) {
      Future.delayed(
        const Duration(milliseconds: 0),

        /// default value equals to CupertinoSliverRefreshControl._defaultRefreshTriggerPullDistance
        () => scrollController?.animateTo(
          -UIConfig.refreshTriggerPullDistance,
          duration: const Duration(milliseconds: 400),
          curve: Curves.ease,
        ),
      );
    }

    state.lastTapTime = DateTime.now();
  }
}
