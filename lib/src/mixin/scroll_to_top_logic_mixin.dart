import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../setting/preference_setting.dart';

mixin Scroll2TopLogicMixin on GetxController {
  final String scroll2TopButtonId = 'scroll2TopButtonId';

  bool inForwardScroll = PreferenceSetting.alwaysShowScroll2TopButton.isFalse;

  Scroll2TopStateMixin get scroll2TopState;

  @override
  void onClose() {
    super.dispose();
    scroll2TopState.scrollController.dispose();
  }

  void jump2Top() {
    if (scroll2TopState.scrollController.hasClients) {
      scroll2TopState.scrollController.jumpTo(0);
    }
  }

  void scroll2Top() {
    if (scroll2TopState.scrollController.hasClients) {
      scroll2TopState.scrollController.animateTo(
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
    if (PreferenceSetting.alwaysShowScroll2TopButton.isTrue) {
      inForwardScroll = false;
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
