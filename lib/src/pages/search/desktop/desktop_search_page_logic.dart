import 'package:jhentai/src/pages/search/base/base_search_page_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_state.dart';

import '../../../model/search_config.dart';
import '../../base/base_page_logic.dart';

class DesktopSearchPageLogic extends BasePageLogic with BaseSearchPageLogicMixin {
  @override
  bool get useSearchConfig => true;

  @override
  bool get autoLoadForFirstTime => false;

  @override
  final DesktopSearchPageState state = DesktopSearchPageState();

  @override
  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('searchConfig: $runtimeType', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
