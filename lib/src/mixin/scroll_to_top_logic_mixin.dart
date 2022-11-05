import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../setting/style_setting.dart';

mixin Scroll2TopLogicMixin on GetxController {
  final String scroll2TopButtonId = 'scroll2TopButtonId';

  bool inForwardScroll = StyleSetting.alwaysShowScroll2TopButton.isTrue;

  Scroll2TopStateMixin get state;

  @override
  void onClose() {
    state.scrollController.dispose();
    super.dispose();
  }

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

  bool onUserScroll(UserScrollNotification notification) {
    bool oldValue = inForwardScroll;

    if (notification.direction == ScrollDirection.forward) {
      inForwardScroll = true;
    } else if (notification.direction == ScrollDirection.reverse) {
      inForwardScroll = false;
    }

    // if always show FAB, update at most once to make sure we display the button actually.
    if (StyleSetting.alwaysShowScroll2TopButton.isTrue) {
      inForwardScroll = true;
      if (!oldValue && inForwardScroll) {
        update([scroll2TopButtonId]);
      }
      return false;
    }

    // update only when scroll direction changed, toggle FAB.
    if (oldValue != inForwardScroll) {
      update([scroll2TopButtonId]);
    }

    return false;
  }
}
