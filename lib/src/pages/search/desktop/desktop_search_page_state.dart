import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_logic.dart';

import '../../../mixin/scroll_to_top_state_mixin.dart';
import 'desktop_search_page_tab_view.dart';

class DesktopSearchPageState with Scroll2TopStateMixin {
  List<DesktopSearchPageTabView> tabs = [];
  List<DesktopSearchPageTabLogic> tabLogics = [];

  int currentTabIndex = 0;
  PageController pageController = PageController();
  Key tabViewKey = UniqueKey();

  ScrollController tabController = ScrollController();

  @override
  ScrollController get scrollController => tabLogics[currentTabIndex].scroll2TopState.scrollController;

  DesktopSearchPageState() {
    DesktopSearchPageTabLogic newTabLogic = DesktopSearchPageTabLogic();
    tabLogics.add(newTabLogic);
    tabs.add(DesktopSearchPageTabView(key: ValueKey(newTabLogic.hashCode.toString()), logic: newTabLogic));
  }
}
