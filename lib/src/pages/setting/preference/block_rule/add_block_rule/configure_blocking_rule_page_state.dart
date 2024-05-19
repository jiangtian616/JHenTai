import 'package:flutter/cupertino.dart';

import '../../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../../service/local_block_rule_service.dart';

class ConfigureBlockingRulePageState with Scroll2TopStateMixin {
  int? ruleId;
  LocalBlockTargetEnum? blockTargetEnum = LocalBlockTargetEnum.gallery;
  LocalBlockAttributeEnum? blockAttributeEnum = LocalBlockAttributeEnum.title;
  LocalBlockPatternEnum? blockPatternEnum = LocalBlockPatternEnum.like;
  String? blockingExpression;

  final TextEditingController textEditingController = TextEditingController();
}
