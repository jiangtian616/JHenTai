import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../model/jh_layout.dart';
import '../model/search_config.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/mixin/search_page_logic_mixin.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';
import '../routes/routes.dart';
import '../service/storage_service.dart';
import '../setting/preference_setting.dart';
import '../setting/style_setting.dart';
import '../widget/eh_search_config_dialog.dart';

SearchConfig? loadSearchPageConfig() {
  Map<String, dynamic>? map = Get.find<StorageService>().read('${ConfigEnum.searchConfig.key}: ${SearchPageLogicMixin.searchPageConfigKey}');
  if (map != null) {
    return SearchConfig.fromJson(map);
  }

  return null;
}

void newSearch(NewSearchArgument argument, [bool forceNewRoute = false]) {
  switch (StyleSetting.actualLayout) {
    case LayoutMode.desktop:
      if (!isRouteAtTop(Routes.desktopSearch)) {
        toRoute(Routes.desktopSearch);
      }

      DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
      if (forceNewRoute) {
        desktopSearchPageLogic.addNewTab(argument);
      } else {
        if (argument.rewriteSearchConfig != null) {
          desktopSearchPageLogic.currentTabLogic.state.searchConfig = argument.rewriteSearchConfig!;
        } else if (argument.keywordSearchBehaviour != null) {
          if (argument.keywordSearchBehaviour == SearchBehaviour.inheritPartially) {
            desktopSearchPageLogic.currentTabLogic.state.searchConfig.keyword = argument.keyword!;
            desktopSearchPageLogic.currentTabLogic.state.searchConfig.tags?.clear();
            desktopSearchPageLogic.currentTabLogic.state.searchConfig.language = null;
            desktopSearchPageLogic.currentTabLogic.state.searchConfig.enableAllCategories();
          } else if (argument.keywordSearchBehaviour == SearchBehaviour.none) {
            desktopSearchPageLogic.currentTabLogic.state.searchConfig = SearchConfig(keyword: argument.keyword);
          }
        }
        desktopSearchPageLogic.handleClearAndRefresh();
      }
      break;
    case LayoutMode.mobileV2:
    case LayoutMode.tabletV2:
      if (SearchPageMobileV2Logic.current == null) {
        toRoute(Routes.mobileV2Search, arguments: argument);
        return;
      }

      if (SearchPageMobileV2Logic.current!.state.loadingState == LoadingState.loading) {
        return;
      }

      if (isRouteAtTop(Routes.mobileV2Search) && !forceNewRoute) {
        SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
        SearchPageMobileV2Logic.current!.state.searchConfig.tags?.clear();
        SearchPageMobileV2Logic.current!.handleClearAndRefresh();
        return;
      }

      toRoute(Routes.mobileV2Search, arguments: argument, preventDuplicates: false);
      break;
    default:
      break;
  }
}

void newSearch(String? keyword, [bool forceNewRoute = false]) {
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    if (!isRouteAtTop(Routes.desktopSearch)) {
      toRoute(Routes.desktopSearch);
    }

    DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
    if (forceNewRoute) {
      desktopSearchPageLogic.addNewTab(keyword: keyword, loadImmediately: true);
    } else {
      desktopSearchPageLogic.currentTabLogic.state.searchConfig.keyword = keyword;
      desktopSearchPageLogic.currentTabLogic.state.searchConfig.tags?.clear();
      desktopSearchPageLogic.handleClearAndRefresh();
    }
    return;
  }

  if (SearchPageMobileV2Logic.current == null) {
    toRoute(Routes.mobileV2Search, arguments: keyword);
    return;
  }

  if (SearchPageMobileV2Logic.current!.state.loadingState == LoadingState.loading) {
    return;
  }

  if (!forceNewRoute && isRouteAtTop(Routes.mobileV2Search)) {
    SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
    SearchPageMobileV2Logic.current!.state.searchConfig.tags?.clear();
    SearchPageMobileV2Logic.current!.handleClearAndRefresh();
    return;
  }

  toRoute(Routes.mobileV2Search, arguments: keyword, preventDuplicates: false);
}

void newSearchWithConfig(SearchConfig searchConfig, [bool forceNewRoute = false]) {
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    if (!isRouteAtTop(Routes.desktopSearch)) {
      toRoute(Routes.desktopSearch);
    }

    DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
    if (forceNewRoute) {
      desktopSearchPageLogic.addNewTab(searchConfig: searchConfig, loadImmediately: true);
    } else {
      desktopSearchPageLogic.currentTabLogic.state.searchConfig = searchConfig.copyWith();
      desktopSearchPageLogic.handleClearAndRefresh();
    }

    return;
  }

  if (SearchPageMobileV2Logic.current == null) {
    toRoute(Routes.mobileV2Search, arguments: searchConfig.copyWith());
    return;
  }

  if (SearchPageMobileV2Logic.current!.state.loadingState == LoadingState.loading) {
    return;
  }

  if (!forceNewRoute && isRouteAtTop(Routes.mobileV2Search)) {
    SearchPageMobileV2Logic.current!.state.searchConfig = searchConfig.copyWith();
    SearchPageMobileV2Logic.current!.handleClearAndRefresh();
    return;
  }

  toRoute(Routes.mobileV2Search, arguments: searchConfig.copyWith(), preventDuplicates: false);
}

Future<void> handleAddQuickSearch() async {
  SearchConfig? originalConfig;
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    originalConfig = Get.find<DesktopSearchPageLogic>().currentTabLogic.state.searchConfig;
  }
  if (StyleSetting.isInV2Layout) {
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
