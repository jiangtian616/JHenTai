import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../base/base_page_logic.dart';

class WatchedPageLogic extends BasePageLogic {
  @override
  bool get autoLoadNeedLogin => true;

  @override
  final WatchedPageState state = WatchedPageState();
}
