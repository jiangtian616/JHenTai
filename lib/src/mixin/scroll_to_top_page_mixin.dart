import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

mixin Scroll2TopPageMixin on Widget {
  Scroll2TopLogicMixin get logic;

  Scroll2TopStateMixin get state;

  Widget buildFloatingActionButton() {
    return GetBuilder<Scroll2TopLogicMixin>(
      id: logic.scroll2TopButtonId,
      global: false,
      init: logic,
      builder: (_) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !logic.inForwardScroll
              ? FloatingActionButton(
                  child: const Icon(Icons.arrow_upward),
                  heroTag: null,
                  onPressed: logic.scroll2Top,
                )
              : null,
        );
      },
    );
  }
}
