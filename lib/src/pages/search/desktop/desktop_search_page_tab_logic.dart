import 'package:jhentai/src/pages/search/base/base_search_page_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_state.dart';

import '../../../model/search_config.dart';
import '../../base/base_page_logic.dart';

class DesktopSearchPageTabLogic extends BasePageLogic with BaseSearchPageLogicMixin {
  @override
  bool get useSearchConfig => true;

  @override
  bool get autoLoadForFirstTime => false;

  @override
  final DesktopSearchPageTabState state = DesktopSearchPageTabState();

  @override
  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('searchConfig: $runtimeType', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
