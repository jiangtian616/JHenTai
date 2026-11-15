import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'base_layout_logic.dart';

/// Shared by layouts which display images in a scrollable list rather than pages
mixin ListLayoutLogicMixin on BaseLayoutLogic {
  ScrollOffsetController get scrollOffsetController;

  List<ItemPosition> getCurrentVisibleItems();

  /// Mouse wheel scrolls the list directly rather than turns page, so tell read page when it can't scroll further
  void onWheelScroll(bool next) {
    if (isAtBoundary(next)) {
      readPageLogic.handleTurnPageBeyondBoundary(next);
    }
  }

  /// Whether the list can't be scrolled further to the end if [next] is true, or to the start otherwise
  bool isAtBoundary(bool next) {
    List<ItemPosition> positions = getCurrentVisibleItems();
    if (positions.isEmpty) {
      return false;
    }

    try {
      ScrollPosition position = scrollOffsetController.position;
      if (next) {
        return positions.last.index == readPageState.readPageInfo.pageCount - 1 && position.extentAfter <= 1;
      }
      return positions.first.index == 0 && position.extentBefore <= 1;
    } catch (_) {
      /// list is not attached
      return false;
    }
  }
}
