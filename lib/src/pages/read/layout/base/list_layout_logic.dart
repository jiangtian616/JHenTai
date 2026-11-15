import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../setting/read_setting.dart';
import 'base_layout_logic.dart';

/// Shared by layouts which display images in a scrollable list rather than pages
mixin ListLayoutLogic on BaseLayoutLogic {
  ItemPositionsListener get itemPositionsListener;

  ItemScrollController get itemScrollController;

  ScrollOffsetController get scrollOffsetController;

  double get screenTurnOffset;

  bool get isActiveListReadDirection;

  @override
  void onInit() {
    super.onInit();
    itemPositionsListener.itemPositions.addListener(_readProgressListener);
  }

  void _readProgressListener() {
    int? firstImageIndex = getCurrentVisibleItems().firstOrNull?.index;
    if (firstImageIndex == null) {
      return;
    }
    readPageLogic.recordReadProgress(firstImageIndex);
  }

  List<ItemPosition> getCurrentVisibleItems() {
    return readPageLogic.filterAndSortItems(itemPositionsListener.itemPositions.value);
  }

  /// Mouse wheel scrolls the list directly rather than turns page, so tell read page when it can't scroll further
  void onWheelScroll(bool next) {
    _turnPageBeyondBoundary(next);
  }

  @override
  void toPrev() {
    if (_turnPageBeyondBoundary(false)) {
      return;
    }
    _turnPage(toImage: toPrevImage, toScreen: toPrevScreen);
  }

  @override
  void toNext() {
    if (_turnPageBeyondBoundary(true)) {
      return;
    }
    _turnPage(toImage: toNextImage, toScreen: toNextScreen);
  }

  bool _turnPageBeyondBoundary(bool next) {
    if (!isAtBoundary(next)) {
      return false;
    }
    readPageLogic.handleTurnPageBeyondBoundary(next);
    return true;
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

  void _turnPage({required void Function() toImage, required void Function() toScreen}) {
    switch (readSetting.turnPageMode.value) {
      case TurnPageMode.image:
        return toImage();
      case TurnPageMode.screen:
        return toScreen();
      case TurnPageMode.adaptive:
        return getCurrentVisibleItems().length > 1 ? toImage() : toScreen();
    }
  }

  void toPrevImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    int targetIndex = firstPosition.itemLeadingEdge < 0 ? firstPosition.index : firstPosition.index - 1;
    toImageIndex(max(targetIndex, 0));
  }

  void toNextImage();

  void toPrevScreen() => _animateScroll(-screenTurnOffset);

  void toNextScreen() => _animateScroll(screenTurnOffset);

  void _animateScroll(double offset) {
    scrollOffsetController.animateScroll(
      offset: offset,
      duration: Duration(milliseconds: readSetting.enablePageTurnAnime.isFalse ? 1 : 200),
    );
  }

  @override
  void scroll2ImageIndex(int imageIndex, [Duration? duration]) {
    itemScrollController.scrollTo(
      index: imageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
    );
    super.scroll2ImageIndex(imageIndex, duration);
  }

  @override
  void enterAutoMode() {
    if (readSetting.autoModeStyle.value == AutoModeStyle.scroll) {
      _enterAutoModeByScroll();
    } else {
      enterAutoModeByTurnPage(
        shouldStop: () {
          if (!isActiveListReadDirection) {
            return true;
          }
          ItemPosition? lastPosition = getCurrentVisibleItems().lastOrNull;
          return lastPosition == null ||
              (lastPosition.index == readPageState.readPageInfo.pageCount - 1 && lastPosition.itemTrailingEdge <= 1.2);
        },
      );
    }
  }

  void _enterAutoModeByScroll() {
    int restPageCount = readPageState.readPageInfo.pageCount - readPageState.readPageInfo.currentImageIndex - 1;
    double totalTime = restPageCount * readSetting.autoModeInterval.value;

    readPageLogic.toggleMenu();

    scrollOffsetController
        .scrollToEnd(
          duration: Duration(milliseconds: (totalTime * 1000).toInt()),
        )
        .then((_) => readPageLogic.closeAutoMode());
  }
}
