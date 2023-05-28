import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_state.dart';

import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import 'desktop_search_page_tab_logic.dart';
import 'desktop_search_page_tab_view.dart';

class DesktopSearchPageLogic extends GetxController with Scroll2TopLogicMixin {
  final String pageId = 'pageId';
  final String tabBarId = 'tabBarId';
  final String tabViewId = 'tabViewId';

  final DesktopSearchPageState state = DesktopSearchPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;
  
  DesktopSearchPageTabLogic get currentTabLogic => state.tabLogics[state.currentTabIndex];

  void handleClearAndRefresh() {
    state.tabLogics[state.currentTabIndex].handleClearAndRefresh();
  }

  void handleTapTab(int index) {
    if (index == state.currentTabIndex) {
      return;
    }

    state.currentTabIndex = index;
    updateSafely([tabBarId]);
    jump2Index(state.currentTabIndex);
  }

  void onPageChanged(int index) {
    state.currentTabIndex = index;
    updateSafely([tabBarId]);
  }

  void addNewTab({String? keyword, SearchConfig? searchConfig, required bool loadImmediately}) {
    DesktopSearchPageTabLogic newTabLogic = DesktopSearchPageTabLogic();
    state.tabLogics.add(newTabLogic);
    state.tabs.add(DesktopSearchPageTabView(key: ValueKey(newTabLogic.hashCode.toString()), logic: newTabLogic));

    state.currentTabIndex = state.tabs.length - 1;
    state.pageController = PageController(initialPage: state.currentTabIndex);
    state.tabViewKey = UniqueKey();
    updateSafely([pageId]);

    state.tabController.jumpTo(state.tabController.position.maxScrollExtent);

    Get.engine.addPostFrameCallback((_) {
      if (searchConfig != null) {
        newTabLogic.state.searchConfig = searchConfig.copyWith();
      } else {
        newTabLogic.state.searchConfig.keyword = keyword;
      }

      if (loadImmediately) {
        newTabLogic.handleClearAndRefresh();
      }
    });
  }

  void deleteTab(int index) {
    if (state.tabLogics.length == 1) {
      return;
    }

    state.tabLogics.removeAt(index).onClose();
    state.tabs.removeAt(index);

    if (index == state.currentTabIndex) {
      state.currentTabIndex = min(state.tabs.length - 1, state.currentTabIndex);
      state.pageController = PageController(initialPage: state.currentTabIndex);
      state.tabViewKey = UniqueKey();
      updateSafely([pageId]);
    }

    if (index < state.currentTabIndex) {
      state.currentTabIndex = state.currentTabIndex - 1;
      state.pageController = PageController(initialPage: state.currentTabIndex);
      updateSafely([pageId]);
    }

    updateSafely([pageId]);
  }

  void jump2Index(int index) {
    return state.pageController.jumpToPage(index);
  }
}
