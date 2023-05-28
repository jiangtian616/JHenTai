import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

mixin Scroll2TopPageMixin on Widget {
  Scroll2TopLogicMixin get scroll2TopLogic;

  Scroll2TopStateMixin get scroll2TopState;

  Widget buildFloatingActionButton() {
    return GetBuilder<Scroll2TopLogicMixin>(
      id: scroll2TopLogic.scroll2TopButtonId,
      global: false,
      init: scroll2TopLogic,
      builder: (_) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !scroll2TopLogic.inForwardScroll
              ? FloatingActionButton(
                  child: const Icon(Icons.arrow_upward),
                  heroTag: null,
                  onPressed: scroll2TopLogic.scroll2Top,
                )
              : null,
        );
      },
    );
  }
}
