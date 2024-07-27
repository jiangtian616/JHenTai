import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../model/jh_layout.dart';
import '../model/search_config.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';
import '../routes/routes.dart';
import '../setting/preference_setting.dart';
import '../setting/style_setting.dart';
import '../widget/eh_search_config_dialog.dart';

Future<void> newSearch({String? keyword, SearchConfig? rewriteSearchConfig, bool forceNewRoute = false}) async {
  assert(keyword != null || rewriteSearchConfig != null);

  switch (styleSetting.actualLayout) {
    case LayoutMode.desktop:
      if (!isRouteAtTop(Routes.desktopSearch)) {
        toRoute(Routes.desktopSearch);
      }

      DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
      if (forceNewRoute) {
        desktopSearchPageLogic.addNewTab(keyword: keyword, rewriteSearchConfig: rewriteSearchConfig);
      } else {
        await desktopSearchPageLogic.currentTabLogic.state.searchConfigInitCompleter.future;
        if (rewriteSearchConfig != null) {
          desktopSearchPageLogic.currentTabLogic.state.searchConfig = rewriteSearchConfig;
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritAll) {
          desktopSearchPageLogic.currentTabLogic.state.searchConfig.keyword = keyword;
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritPartially) {
          desktopSearchPageLogic.currentTabLogic.state.searchConfig.keyword = keyword;
          desktopSearchPageLogic.currentTabLogic.state.searchConfig.tags?.clear();
          desktopSearchPageLogic.currentTabLogic.state.searchConfig.language = null;
          desktopSearchPageLogic.currentTabLogic.state.searchConfig.enableAllCategories();
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.none) {
          desktopSearchPageLogic.currentTabLogic.state.searchConfig = SearchConfig(keyword: keyword);
        }
        desktopSearchPageLogic.handleClearAndRefresh();
      }
      return;
    case LayoutMode.mobileV2:
    case LayoutMode.tabletV2:
      if (SearchPageMobileV2Logic.current == null) {
        toRoute(
          Routes.mobileV2Search,
          arguments: NewSearchArgument(
            keyword: keyword,
            keywordSearchBehaviour: preferenceSetting.searchBehaviour.value,
            rewriteSearchConfig: rewriteSearchConfig,
          ),
        );
        return;
      }

      if (SearchPageMobileV2Logic.current!.state.loadingState == LoadingState.loading) {
        return;
      }

      if (isRouteAtTop(Routes.mobileV2Search) && !forceNewRoute) {
        await SearchPageMobileV2Logic.current!.state.searchConfigInitCompleter.future;
        if (rewriteSearchConfig != null) {
          SearchPageMobileV2Logic.current!.state.searchConfig = rewriteSearchConfig;
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritAll) {
          SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritPartially) {
          SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
          SearchPageMobileV2Logic.current!.state.searchConfig.tags?.clear();
          SearchPageMobileV2Logic.current!.state.searchConfig.language = null;
          SearchPageMobileV2Logic.current!.state.searchConfig.enableAllCategories();
        } else if (preferenceSetting.searchBehaviour.value == SearchBehaviour.none) {
          SearchPageMobileV2Logic.current!.state.searchConfig = SearchConfig(keyword: keyword);
        }
        SearchPageMobileV2Logic.current!.handleClearAndRefresh();
        return;
      }

      toRoute(
        Routes.mobileV2Search,
        arguments: NewSearchArgument(
          keyword: keyword,
          keywordSearchBehaviour: preferenceSetting.searchBehaviour.value,
          rewriteSearchConfig: rewriteSearchConfig,
        ),
        preventDuplicates: false,
      );
      return;
    default:
      return;
  }
}

Future<void> handleAddQuickSearch() async {
  SearchConfig? originalConfig;
  if (styleSetting.actualLayout == LayoutMode.desktop) {
    originalConfig = Get.find<DesktopSearchPageLogic>().currentTabLogic.state.searchConfig;
  }
  if (styleSetting.isInV2Layout) {
    originalConfig = SearchPageMobileV2Logic.current?.state.searchConfig;
  }

  Map<String, dynamic>? result = await Get.dialog(
    EHSearchConfigDialog(quickSearchName: originalConfig?.computeFullKeywords(), searchConfig: originalConfig, type: EHSearchConfigDialogType.add),
  );

  if (result == null) {
    return;
  }

  String quickSearchName = result['quickSearchName'];
  SearchConfig searchConfig = result['searchConfig'];
  Get.find<QuickSearchService>().addQuickSearch(quickSearchName, searchConfig);
}
