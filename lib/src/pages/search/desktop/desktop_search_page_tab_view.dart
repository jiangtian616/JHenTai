import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_state.dart';

import '../../../config/ui_config.dart';
import '../../base/base_page.dart';
import '../mixin/search_page_mixin.dart';
import '../mixin/search_page_state_mixin.dart';

class DesktopSearchPageTabView extends BasePage<DesktopSearchPageTabLogic, DesktopSearchPageTabState>
    with SearchPageMixin<DesktopSearchPageTabLogic, DesktopSearchPageTabState> {
  const DesktopSearchPageTabView({Key? key, required this.logic}) : super(key: key, showJumpButton: true, showScroll2TopButton: true);

  @override
  final DesktopSearchPageTabLogic logic;

  @override
  DesktopSearchPageTabState get state => logic.state;

  @override
  AppBar? buildAppBar(BuildContext context) => null;

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        buildHeader(context),
        if (state.bodyType == SearchPageBodyType.suggestionAndHistory)
          Expanded(
            child: GetBuilder<DesktopSearchPageTabLogic>(
              global: false,
              init: logic,
              id: logic.suggestionBodyId,
              builder: (_) => buildSuggestionAndHistoryBody(),
            ),
          )
        else if (state.hasSearched)
          Expanded(
            child: GetBuilder<DesktopSearchPageTabLogic>(
              global: false,
              init: logic,
              id: logic.galleryBodyId,
              builder: (_) => super.buildBody(context),
            ),
          ),
      ],
    );
  }

  Widget buildHeader(BuildContext context) {
    return Container(
      height: UIConfig.desktopSearchBarHeight,
      margin: const EdgeInsets.only(left: 2, right: 2),
      child: Row(
        children: [
          Expanded(child: buildSearchField().marginSymmetric(horizontal: 16)),
          ...buildActionButtons(),
        ],
      ),
    );
  }
}
