import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_state.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';

import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../setting/preference_setting.dart';
import '../../../utils/uuid_util.dart';
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

  void addNewTab(NewSearchArgument argument) {
    DesktopSearchPageTabLogic newTabLogic = DesktopSearchPageTabLogic();
    if (argument.rewriteSearchConfig != null) {
      newTabLogic.state.searchConfig = argument.rewriteSearchConfig!;
    } else if (argument.keywordSearchBehaviour != null) {
      if (argument.keywordSearchBehaviour == SearchBehaviour.inheritPartially) {
        newTabLogic.state.searchConfig.keyword = argument.keyword;
        newTabLogic.state.searchConfig.language = null;
        newTabLogic.state.searchConfig.enableAllCategories();
      } else if (argument.keywordSearchBehaviour == SearchBehaviour.none) {
        newTabLogic.state.searchConfig = SearchConfig(keyword: argument.keyword);
      }
    }

    state.tabLogics.add(newTabLogic);
    state.tabs.add(DesktopSearchPageTabView(key: ValueKey(newUUID()), logic: newTabLogic));

    state.currentTabIndex = state.tabs.length - 1;
    state.pageController = PageController(initialPage: state.currentTabIndex);
    state.tabViewKey = Key(newUUID());
    updateSafely([pageId]);

    state.tabController.jumpTo(state.tabController.position.maxScrollExtent);

    if (argument.loadImmediately) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        newTabLogic.handleClearAndRefresh();
      });
    }
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
      state.tabViewKey = Key(newUUID());
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
