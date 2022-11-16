import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../model/jh_layout.dart';
import '../model/search_config.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';
import '../routes/routes.dart';
import '../setting/style_setting.dart';
import '../widget/eh_search_config_dialog.dart';

void newSearch(String? keyword) {
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
    if (desktopSearchPageLogic.state.loadingState == LoadState.loading) {
      return;
    }
    toRoute(Routes.desktopSearch);
    desktopSearchPageLogic.state.searchConfig.keyword = keyword;
    desktopSearchPageLogic.state.searchConfig.tags?.clear();
    desktopSearchPageLogic.handleClearAndRefresh();
    return;
  }

  if (SearchPageMobileV2Logic.current == null) {
    toRoute(Routes.mobileV2Search, arguments: keyword);
    return;
  }

  if (SearchPageMobileV2Logic.current!.state.loadingState == LoadState.loading) {
    return;
  }

  if (isRouteAtTop(Routes.mobileV2Search)) {
    SearchPageMobileV2Logic.current!.state.searchConfig.keyword = keyword;
    SearchPageMobileV2Logic.current!.state.searchConfig.tags?.clear();
    SearchPageMobileV2Logic.current!.handleClearAndRefresh();
    return;
  }

  toRoute(Routes.mobileV2Search, arguments: keyword);
}

void newSearchWithConfig(SearchConfig searchConfig) {
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
    if (desktopSearchPageLogic.state.loadingState == LoadState.loading) {
      return;
    }

    toRoute(Routes.desktopSearch);
    desktopSearchPageLogic.state.searchConfig = searchConfig.copyWith();
    desktopSearchPageLogic.handleClearAndRefresh();
    return;
  }

  /// close drawer
  backRoute(currentRoute: Routes.mobileV2Search);

  if (SearchPageMobileV2Logic.current == null) {
    toRoute(Routes.mobileV2Search, arguments: searchConfig.copyWith());
    return;
  }

  if (SearchPageMobileV2Logic.current!.state.loadingState == LoadState.loading) {
    return;
  }

  if (isRouteAtTop(Routes.mobileV2Search)) {
    SearchPageMobileV2Logic.current!.state.searchConfig = searchConfig.copyWith();
    SearchPageMobileV2Logic.current!.handleClearAndRefresh();
    return;
  }

  toRoute(Routes.mobileV2Search, arguments: searchConfig.copyWith());
}

Future<void> handleAddQuickSearch() async {
  SearchConfig? originalConfig;
  if (StyleSetting.actualLayout == LayoutMode.desktop) {
    originalConfig = Get.find<DesktopSearchPageLogic>().state.searchConfig;
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
