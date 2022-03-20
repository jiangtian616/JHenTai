import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/gallerys/gallerys_view.dart';

import '../../config/global_config.dart';
import 'home_page_state.dart';

class HomePageLogic extends GetxController {
  final HomePageState state = HomePageState();

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

    ScrollController? scrollController = galleryListkey.currentState?.innerController;

    /// no gallerys data
    if (scrollController?.hasClients == false) {
      return;
    }

    /// scroll to top
    if ((scrollController?.positions as List<ScrollPosition>)[index].pixels != 0) {
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
