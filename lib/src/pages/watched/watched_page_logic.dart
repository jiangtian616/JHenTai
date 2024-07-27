import 'dart:convert';

import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../../enum/config_enum.dart';
import '../../model/search_config.dart';
import '../../service/local_config_service.dart';
import '../base/base_page_logic.dart';

class WatchedPageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  bool get autoLoadNeedLogin => true;

  @override
  final WatchedPageState state = WatchedPageState();

  @override
  Future<void> saveSearchConfig(SearchConfig searchConfig) async {
    await localConfigService.write(
      configKey: ConfigEnum.searchConfig,
      subConfigKey: searchConfigKey,
      value: jsonEncode(searchConfig.copyWith(keyword: '', tags: [])),
    );
  }
}
