import 'package:flutter/cupertino.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';

abstract class GridBasePageState with Scroll2TopStateMixin {
  String? currentGroup;

  bool get isAtRoot => currentGroup == null;

  List<String> get allRootGroups;

  List get currentGalleryObjects => galleryObjectsWithGroup(currentGroup);

  List galleryObjectsWithGroup(String? groupName);

  final ScrollController rootScrollController = ScrollController();
  final ScrollController galleryScrollController = ScrollController();

  @override
  ScrollController get scrollController => isAtRoot ? rootScrollController : galleryScrollController;
}
