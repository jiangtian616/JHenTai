import '../../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../../service/local_block_rule_service.dart';

class ConfigureBlockingRulePageState with Scroll2TopStateMixin {
  late String groupId;

  List<LocalBlockRule> rules = [];
}
