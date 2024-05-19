import 'package:jhentai/src/service/local_block_rule_service.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../widget/grouped_list.dart';

class BlockingRulePageState with Scroll2TopStateMixin {
  bool showGroup = false;
  final GroupedListController<String, LocalBlockRule> groupedListController = GroupedListController<String, LocalBlockRule>();
  
  List<LocalBlockRule> rules = [];
}
