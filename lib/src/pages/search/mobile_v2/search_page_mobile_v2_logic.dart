import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2_state.dart';

import '../../../model/search_config.dart';
import '../../base/base_page_logic.dart';
import '../mixin/search_page_logic_mixin.dart';

class SearchPageMobileV2Logic extends BasePageLogic with SearchPageLogicMixin {
  @override
  bool get useSearchConfig => true;

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
      handleClearAndRefresh();
    }

    if (Get.arguments is SearchConfig) {
      state.searchConfig = (Get.arguments as SearchConfig).copyWith();
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
    storageService.write('searchConfig: $runtimeType', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
