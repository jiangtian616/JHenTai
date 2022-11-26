import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class LocalGalleryPageState with Scroll2TopStateMixin {
  LoadingState loadingState = LoadingState.loading;

  String currentPath = '';

  bool aggregateDirectories = false;

  final Set<String> removedGalleryTitles = {};
}
