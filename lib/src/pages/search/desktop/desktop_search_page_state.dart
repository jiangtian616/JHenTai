import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';

import '../../base/base_page_state.dart';
import '../../layout/desktop/desktop_layout_page_logic.dart';

class DesktopSearchPageState extends BasePageState with BaseSearchPageStateMixin {

  DesktopSearchPageState() {
    searchFieldFocusNode.onKeyEvent = (_, KeyEvent event) {
      if (event is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        Get.find<DesktopLayoutPageLogic>().state.leftColumnFocusScopeNode.nextFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
  }
}
