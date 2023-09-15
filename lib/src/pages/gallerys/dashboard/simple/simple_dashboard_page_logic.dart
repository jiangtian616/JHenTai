import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/simple/simple_dashboard_page_state.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';

class SimpleDashboardPageLogic extends BasePageLogic {
  @override
  bool get useSearchConfig => true;

  @override
  String get searchConfigKey => 'DashboardPageLogic';
  
  @override
  SimpleDashboardPageState state = SimpleDashboardPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;
}
