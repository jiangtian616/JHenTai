import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class TagSetsState {
  int currentTagSetIndex = 0;
  List<String> tagSetNames = <String>[];
  List<TagSet> tagSets = <TagSet>[];

  late String apikey;

  LoadingState loadingState = LoadingState.idle;
  LoadingState updateTagState = LoadingState.idle;
  LoadingState deleteTagState = LoadingState.idle;
}
