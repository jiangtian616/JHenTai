import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

class LocalGalleryPageState with Scroll2TopStateMixin {
  String currentPath = '';

  bool aggregateDirectories = false;

  final Set<String> removedGalleryTitles = {};
}
