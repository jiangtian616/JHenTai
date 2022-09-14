import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_logic.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2_state.dart';

import '../../../model/search_config.dart';
import '../../base/base_page_logic.dart';

class SearchPageMobileV2Logic extends BasePageLogic with BaseSearchPageLogicMixin {
  @override
  int get tabIndex => 1;

  @override
  bool get useSearchConfig => false;

  @override
  bool get autoLoadForFirstTime => false;

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
    if (Get.arguments is String) {
      state.searchConfig.keyword = Get.arguments;
      clearAndRefresh();
    }

    if (Get.arguments is SearchConfig) {
      state.searchConfig = (Get.arguments as SearchConfig).copyWith();
      clearAndRefresh();
    }

    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
    stack.remove(this);
  }
}
