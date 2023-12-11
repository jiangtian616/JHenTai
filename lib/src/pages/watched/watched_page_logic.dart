import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../../model/search_config.dart';
import '../base/base_page_logic.dart';

class WatchedPageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  bool get autoLoadNeedLogin => true;

  @override
  final WatchedPageState state = WatchedPageState();

  @override
  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('searchConfig: $searchConfigKey', searchConfig.copyWith(keyword: '', tags: []).toJson());
  }
}
