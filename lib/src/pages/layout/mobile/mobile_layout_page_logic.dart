import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/ui_config.dart';
import '../../gallerys/nested/nested_gallerys_page.dart';
import '../../gallerys/nested/nested_gallerys_page_logic.dart';
import 'mobile_layout_page_state.dart';

class MobileLayoutPageLogic extends GetxController {
  final MobileLayoutPageState state = MobileLayoutPageState();

  /// tap another bar -> change index
  /// at gallery bar and tap gallery bar again -> scroll to top
  /// at gallery bar and tap gallery bar twice -> scroll to top and refresh
  void handleTapNavigationBar(int index) {
    int prevIndex = state.currentIndex;
    state.currentIndex = index;

    if (prevIndex != index) {
      return;
    }
    if (index != 0) {
      return;
    }

    ScrollController? scrollController = galleryListKey.currentState?.innerController;

    /// no popular_page.dart data
    if (scrollController?.hasClients == false) {
      return;
    }

    /// scroll to top
    if ((scrollController?.positions as List<ScrollPosition>).any((position) => position.pixels != 0)) {
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
      /// reset [prevPageIndexToLoad] to refresh rather than load prev page
      NestedGallerysPageLogic gallerysViewLogic = Get.find<NestedGallerysPageLogic>();
      gallerysViewLogic.state.prevPageIndexToLoad[gallerysViewLogic.tabController.index] = null;

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
