import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class TagSetsState with Scroll2TopStateMixin {
  int currentTagSetNo = 1;
  List<({int number, String name})> tagSets = [];
  List<WatchedTag> tags = <WatchedTag>[];

  late String apikey;

  LoadingState loadingState = LoadingState.idle;
  LoadingState updateTagState = LoadingState.idle;
}
