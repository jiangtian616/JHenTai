import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

mixin Scroll2TopLogicMixin on GetxController {
  Scroll2TopStateMixin get state;

  void jump2Top() {
    if (state.scrollController.hasClients) {
      state.scrollController.jumpTo(0);
    }
  }

  void scroll2Top() {
    if (state.scrollController.hasClients) {
      state.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }
  }

  @override
  void onClose() {
    state.scrollController.dispose();
    super.dispose();
  }
}
