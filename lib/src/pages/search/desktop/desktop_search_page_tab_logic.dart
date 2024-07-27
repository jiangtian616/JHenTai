import 'dart:convert';

import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_state.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';

import '../../../enum/config_enum.dart';
import '../../../model/search_config.dart';
import '../../../service/local_config_service.dart';
import '../../../setting/preference_setting.dart';
import '../../base/base_page_logic.dart';
import '../mixin/search_page_logic_mixin.dart';

class DesktopSearchPageTabLogic extends BasePageLogic with SearchPageLogicMixin {
  final NewSearchArgument newSearchArgument;
  final bool loadImmediately;

  @override
  final DesktopSearchPageTabState state = DesktopSearchPageTabState();

  DesktopSearchPageTabLogic(this.newSearchArgument, this.loadImmediately);

  @override
  Future<void> onReady() async {
    await super.onReady();

    String? keyword = newSearchArgument.keyword;
    SearchBehaviour searchBehaviour = newSearchArgument.keywordSearchBehaviour ?? preferenceSetting.searchBehaviour.value;
    SearchConfig? rewriteSearchConfig = newSearchArgument.rewriteSearchConfig;

    if (rewriteSearchConfig != null) {
      state.searchConfig = rewriteSearchConfig.copyWith();
    } else if (searchBehaviour == SearchBehaviour.inheritAll) {
      state.searchConfig.keyword = keyword;
    } else if (searchBehaviour == SearchBehaviour.inheritPartially) {
      state.searchConfig.keyword = keyword;
      state.searchConfig.language = null;
      state.searchConfig.enableAllCategories();
    } else if (searchBehaviour == SearchBehaviour.none) {
      state.searchConfig = SearchConfig(keyword: keyword);
    }

    if (loadImmediately) {
      handleClearAndRefresh();
    }
  }

  @override
  Future<void> saveSearchConfig(SearchConfig searchConfig) async {
    await localConfigService.write(
      configKey: ConfigEnum.searchConfig,
      subConfigKey: searchConfigKey,
      value: jsonEncode(searchConfig.copyWith(keyword: '', tags: [])),
    );
  }
}
