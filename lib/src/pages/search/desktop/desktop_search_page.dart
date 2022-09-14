import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/base/base_search_page.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../../config/ui_config.dart';
import '../../base/base_page.dart';
import '../base/base_search_page_state.dart';

class DesktopSearchPage extends BasePage<DesktopSearchPageLogic, DesktopSearchPageState>
    with BaseSearchPageMixin<DesktopSearchPageLogic, DesktopSearchPageState> {
  const DesktopSearchPage({Key? key}) : super(key: key, showJumpButton: true, showScroll2TopButton: true);

  @override
  DesktopSearchPageLogic get logic => Get.put<DesktopSearchPageLogic>(DesktopSearchPageLogic(), permanent: true);

  @override
  DesktopSearchPageState get state => Get.find<DesktopSearchPageLogic>().state;

  @override
  AppBar? buildAppBar(BuildContext context) => null;

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        buildHeader(context),
        if (state.bodyType == SearchPageBodyType.suggestionAndHistory)
          Expanded(
            child: GetBuilder<DesktopSearchPageLogic>(
              id: logic.suggestionBodyId,
              builder: (_) => buildSuggestionAndHistoryBody(),
            ),
          )
        else if (state.hasSearched)
          Expanded(
            child: GetBuilder<DesktopSearchPageLogic>(
              id: logic.galleryBodyId,
              builder: (_) => super.buildBody(context),
            ),
          ),
      ],
    );
  }

  Widget buildHeader(BuildContext context) {
    return Container(
      height: UIConfig.searchBarHeight,
      margin: const EdgeInsets.only(top: 8, bottom: 8, left: 2, right: 2),
      child: Row(
        children: [
          Expanded(child: buildSearchField().marginSymmetric(horizontal: 16)),
          ExcludeFocus(
            child: IconButton(icon: const Icon(Icons.attach_file), onPressed: logic.handleFileSearch),
          ),
          if (state.gallerys.isNotEmpty && state.bodyType == SearchPageBodyType.gallerys)
            ExcludeFocus(
              child: FadeIn(
                child: IconButton(
                  icon: const Icon(FontAwesomeIcons.paperPlane, size: 18),
                  onPressed: logic.handleTapJumpButton,
                ).marginOnly(bottom: 2),
              ),
            ),
          ExcludeFocus(
            child: IconButton(
              icon: Icon(state.bodyType == SearchPageBodyType.gallerys ? Icons.switch_left : Icons.switch_right, size: 30),
              onPressed: logic.toggleBodyType,
            ),
          ),
          ExcludeFocus(
              child: IconButton(icon: const Icon(Icons.filter_alt), onPressed: () => logic.handleTapFilterButton(EHSearchConfigDialogType.filter))),
          ExcludeFocus(
            child: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => toRoute(Routes.quickSearch)),
          ),
        ],
      ),
    );
  }
}
