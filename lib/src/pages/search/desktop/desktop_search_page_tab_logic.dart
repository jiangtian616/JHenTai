import 'package:jhentai/src/pages/search/desktop/desktop_search_page_tab_state.dart';

import '../../../enum/storage_enum.dart';
import '../../../model/search_config.dart';
import '../../base/base_page_logic.dart';
import '../mixin/search_page_logic_mixin.dart';

class DesktopSearchPageTabLogic extends BasePageLogic with SearchPageLogicMixin {
  @override
  final DesktopSearchPageTabState state = DesktopSearchPageTabState();

  @override
  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('${StorageEnum.searchConfig.key}: $searchConfigKey', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
