import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/pages/home/navigation_view/gallerys/gallerys_view_logic.dart';

import '../../config/global_config.dart';
import 'home_page_state.dart';
import 'navigation_view/gallerys/gallerys_view.dart';

class HomePageLogic extends GetxController {
  final HomePageState state = HomePageState();

  /// tap another bar -> change index
  /// at gallery bar and tap gallery bar again -> scroll to top
  /// at gallery bar and tap gallery bar twice -> scroll to top and refresh
  void handleTapNavigationBar(int index) {
    if (state.currentNavigationIndex != index) {
      state.currentNavigationIndex = index;
      update();
      return;
    }

    if (index != 0) {
      return;
    }

    ScrollController? scrollController = galleryListkey.currentState?.innerController;

    /// no gallerys data
    if (scrollController?.hasClients == false) {
      return;
    }

    /// scroll to top
    scrollController?.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.ease,
    );

    if (state.lastTapTime == null) {
      state.lastTapTime = DateTime.now();
      return;
    }

    if (DateTime.now().difference(state.lastTapTime!).inMilliseconds <= 200) {
      /// default value equals to CupertinoSliverRefreshControl._defaultRefreshTriggerPullDistance
      scrollController?.animateTo(
        -GlobalConfig.refreshTriggerPullDistance,
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }

    state.lastTapTime = DateTime.now();
  }
}
