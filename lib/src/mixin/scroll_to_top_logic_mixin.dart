import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../setting/preference_setting.dart';

mixin Scroll2TopLogicMixin on GetxController {
  final String scroll2TopButtonId = 'scroll2TopButtonId';

  Worker? scroll2TopSettingWorker;

  Scroll2TopStateMixin get scroll2TopState;

  bool get shouldDisplayFAB =>
      preferenceSetting.hideScroll2TopButton.value == Scroll2TopButtonModeEnum.never ||
      (preferenceSetting.hideScroll2TopButton.value == Scroll2TopButtonModeEnum.scrollDown && scroll2TopState.isScrollingDown) ||
      (preferenceSetting.hideScroll2TopButton.value == Scroll2TopButtonModeEnum.scrollUp && !scroll2TopState.isScrollingDown);

  @override
  void onInit() {
    super.onInit();
    scroll2TopSettingWorker = ever(preferenceSetting.hideScroll2TopButton, (_) => updateSafely([scroll2TopButtonId]));
  }

  @override
  void onClose() {
    scroll2TopState.scrollController.dispose();
    scroll2TopSettingWorker?.dispose();
    super.onClose();
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
    bool oldValue = scroll2TopState.isScrollingDown;

    if (notification.direction == ScrollDirection.forward) {
      scroll2TopState.isScrollingDown = true;
    } else if (notification.direction == ScrollDirection.reverse) {
      scroll2TopState.isScrollingDown = false;
    }

    // if always or never show FAB, we don't need to update
    if (preferenceSetting.hideScroll2TopButton.value == Scroll2TopButtonModeEnum.never || preferenceSetting.hideScroll2TopButton.value == Scroll2TopButtonModeEnum.always) {
      return false;
    }

    // update only when scroll direction changed, toggle FAB.
    if (oldValue != scroll2TopState.isScrollingDown) {
      updateSafely([scroll2TopButtonId]);
    }

    return false;
  }
}
