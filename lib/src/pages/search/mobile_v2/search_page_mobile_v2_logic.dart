import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/mixin/new_search_argument.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2_state.dart';

import '../../../enum/config_enum.dart';
import '../../../model/search_config.dart';
import '../../../setting/preference_setting.dart';
import '../../base/base_page_logic.dart';
import '../mixin/search_page_logic_mixin.dart';

class SearchPageMobileV2Logic extends BasePageLogic with SearchPageLogicMixin {
  @override
  final SearchPageMobileV2State state = SearchPageMobileV2State();

  /// there may be more than one DetailsPages in route stack at same time, eg: tag a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  static final List<SearchPageMobileV2Logic> stack = <SearchPageMobileV2Logic>[];

  static SearchPageMobileV2Logic? get current => stack.isEmpty ? null : stack.last;

  SearchPageMobileV2Logic() {
    stack.add(this);
  }

  @override
  void onReady() {
    String? keyword;
    SearchBehaviour searchBehaviour = PreferenceSetting.searchBehaviour.value;
    SearchConfig? rewriteSearchConfig;

    if (Get.arguments is NewSearchArgument) {
      NewSearchArgument argument = Get.arguments;

      keyword = argument.keyword;
      searchBehaviour = argument.keywordSearchBehaviour ?? PreferenceSetting.searchBehaviour.value;
      rewriteSearchConfig = argument.rewriteSearchConfig;
    }

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

    if (Get.arguments is NewSearchArgument) {
      handleClearAndRefresh();
    }

    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
    stack.remove(this);
  }

  @override
  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('${ConfigEnum.searchConfig.key}: $searchConfigKey', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
