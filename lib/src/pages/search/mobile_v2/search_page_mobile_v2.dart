import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/base/base_search_page.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2_logic.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../../../setting/style_setting.dart';
import '../../../widget/eh_search_config_dialog.dart';
import '../../base/base_page.dart';
import '../base/base_search_page_state.dart';
import '../quick_search/quick_search_page.dart';

class SearchPageMobileV2 extends BasePage<SearchPageMobileV2Logic, SearchPageMobileV2State>
    with BaseSearchPageMixin<SearchPageMobileV2Logic, SearchPageMobileV2State> {
  final String tag = UniqueKey().toString();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  SearchPageMobileV2({Key? key}) : super(key: key, showJumpButton: true, showScroll2TopButton: true) {
    logic = Get.put(SearchPageMobileV2Logic(), tag: tag);
    state = logic.state;
  }

  @override
  late final SearchPageMobileV2Logic logic;

  @override
  late final SearchPageMobileV2State state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SearchPageMobileV2Logic>(
      global: false,
      init: logic,
      builder: (_) => Obx(
        () => Scaffold(
          key: scaffoldKey,
          appBar: buildAppBar(context),
          endDrawer: Drawer(width: 278, child: QuickSearchPage()),
          endDrawerEnableOpenDragGesture: StyleSetting.enableQuickSearchDrawerGesture.isTrue,
          body: SafeArea(child: buildBody(context)),
          floatingActionButton: buildFloatingActionButton(context),
          resizeToAvoidBottomInset: false,
        ),
      ),
    );
  }

  @override
  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => backRoute(currentRoute: Routes.mobileV2Search)),
      title: buildSearchField(),
      titleSpacing: 0,
      actions: _buildHeaderActions(),
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        if (state.bodyType == SearchPageBodyType.suggestionAndHistory)
          Expanded(
            child: GetBuilder<SearchPageMobileV2Logic>(
              id: logic.suggestionBodyId,
              global: false,
              init: logic,
              builder: (_) => buildSuggestionAndHistoryBody(),
            ),
          )
        else if (state.hasSearched)
          Expanded(
            child: GetBuilder<SearchPageMobileV2Logic>(
              id: logic.galleryBodyId,
              global: false,
              init: logic,
              builder: (_) => super.buildBody(context),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      InkResponse(
        child: const Icon(Icons.attach_file, size: 22),
        onTap: logic.handleFileSearch,
      ).marginOnly(right: 12, left: 8, top: 1),
      if (state.gallerys.isNotEmpty && state.bodyType == SearchPageBodyType.gallerys)
        FadeIn(
          child: InkResponse(
            child: const Icon(FontAwesomeIcons.paperPlane, size: 18),
            onTap: () {
              state.searchFieldFocusNode.unfocus();
              logic.handleTapJumpButton();
            },
          ).marginOnly(right: 16),
        ),
      InkResponse(
        child: Icon(state.bodyType == SearchPageBodyType.gallerys ? Icons.switch_left : Icons.switch_right, size: 28),
        onTap: logic.toggleBodyType,
      ).marginOnly(right: 12),
      InkResponse(
        child: const Icon(Icons.filter_alt),
        onTap: () {
          state.searchFieldFocusNode.unfocus();
          logic.handleTapFilterButton(EHSearchConfigDialogType.filter);
        },
      ).marginOnly(right: 12),
      InkResponse(
        child: const Icon(Icons.more_vert),
        onTap: () {
          state.searchFieldFocusNode.unfocus();
          scaffoldKey.currentState?.openEndDrawer();
        },
      ).marginOnly(right: 12, top: 1),
    ];
  }
}
