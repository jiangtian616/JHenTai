import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../base/base_layout_logic.dart';
import 'horizontal_list_layout_state.dart';

class HorizontalListLayoutLogic extends BaseLayoutLogic {
  HorizontalListLayoutState state = HorizontalListLayoutState();

  @override
  void onInit() {
    super.onInit();

    /// record reading progress and sync thumbnails list index
    state.itemPositionsListener.itemPositions.addListener(_readProgressListener);
  }

  @override
  void onClose() {
    state.itemPositionsListener.itemPositions.removeListener(_readProgressListener);
    super.onClose();
  }

  @override
  void toLeft() {
    if (readSetting.isInRight2LeftDirection) {
      toNext();
    } else {
      toPrev();
    }
  }

  @override
  void toRight() {
    if (readSetting.isInRight2LeftDirection) {
      toPrev();
    } else {
      toNext();
    }
  }

  /// to prev image or screen
  @override
  void toPrev() {
    switch (readSetting.turnPageMode.value) {
      case TurnPageMode.image:
        return _toPrevImage();
      case TurnPageMode.screen:
        return _toPrevScreen();
      case TurnPageMode.adaptive:
        List<ItemPosition> positions = getCurrentVisibleItems();
        if (positions.length > 1) {
          return _toPrevImage();
        }
        return _toPrevScreen();
    }
  }

  /// to next image or screen
  @override
  void toNext() {
    switch (readSetting.turnPageMode.value) {
      case TurnPageMode.image:
        return _toNextImage();
      case TurnPageMode.screen:
        return _toNextScreen();
      case TurnPageMode.adaptive:
        List<ItemPosition> positions = getCurrentVisibleItems();
        if (positions.length > 1) {
          return _toNextImage();
        }
        return _toNextScreen();
    }
  }

  /// jump to a certain image
  @override
  void jump2ImageIndex(int imageIndex) {
    super.jump2ImageIndex(imageIndex);

    /// Method [jumpTo] leads to redrawing, so wo use scrollTo
    state.itemScrollController.scrollTo(index: imageIndex, duration: const Duration(milliseconds: 1));
  }

  /// scroll to a certain image
  @override
  void scroll2ImageIndex(int imageIndex, [Duration? duration]) {
    state.itemScrollController.scrollTo(
      index: imageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
    );
    super.scroll2ImageIndex(imageIndex, duration);
  }

  /// scroll or jump until one image in viewport currently reach top
  void _toPrevImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    int targetIndex = firstPosition.itemLeadingEdge < 0 ? firstPosition.index : firstPosition.index - 1;
    toImageIndex(max(targetIndex, 0));
  }

  /// scroll or jump until last image in viewport currently reach top
  void _toNextImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    toImageIndex(min(firstPosition.index + 1, readPageState.readPageInfo.pageCount - 1));
  }

  void _toPrevScreen() {
    if (readSetting.enablePageTurnAnime.isFalse) {
      state.scrollOffsetController.animateScroll(
        offset: -fullScreenWidth,
        duration: const Duration(milliseconds: 1),
      );
    } else {
      state.scrollOffsetController.animateScroll(
        offset: -fullScreenWidth,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void _toNextScreen() {
    if (readSetting.enablePageTurnAnime.isFalse) {
      state.scrollOffsetController.animateScroll(
        offset: fullScreenWidth,
        duration: const Duration(milliseconds: 1),
      );
    } else {
      state.scrollOffsetController.animateScroll(
        offset: fullScreenWidth,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void enterAutoMode() {
    if (readSetting.autoModeStyle.value == AutoModeStyle.scroll) {
      _enterAutoModeByScroll();
    } else {
      _enterAutoModeByTurnPage();
    }
  }

  void _enterAutoModeByScroll() {
    int restPageCount = readPageState.readPageInfo.pageCount - readPageState.readPageInfo.currentImageIndex - 1;
    double totalTime = restPageCount * readSetting.autoModeInterval.value;

    readPageLogic.toggleMenu();

    state.scrollOffsetController
        .scrollToEnd(
          duration: Duration(milliseconds: (totalTime * 1000).toInt()),
        )
        .then((_) => readPageLogic.closeAutoMode());
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (readSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read setting
        if (readSetting.readDirection.value != ReadDirection.left2rightList && readSetting.readDirection.value != ReadDirection.right2leftList) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// stop when at bottom
        ItemPosition? lastPosition = getCurrentVisibleItems().lastOrNull;

        if (lastPosition == null) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// sometimes itemTrailingEdge is not equal to 1.0
        if (lastPosition.index == readPageState.readPageInfo.pageCount - 1 && lastPosition.itemTrailingEdge <= 1.2) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        toNext();
      },
    );
  }

  List<ItemPosition> getCurrentVisibleItems() {
    return readPageLogic.filterAndSortItems(state.itemPositionsListener.itemPositions.value);
  }

  void _readProgressListener() {
    int? firstImageIndex = getCurrentVisibleItems().firstOrNull?.index;

    if (firstImageIndex == null) {
      return;
    }

    readPageLogic.recordReadProgress(firstImageIndex);
    readPageLogic.syncThumbnails(firstImageIndex);
  }

  @override
  Size getPlaceHolderSize(int imageIndex) {
    if (readPageState.imageContainerSizes[imageIndex] != null) {
      return readPageState.imageContainerSizes[imageIndex]!;
    }
    return Size((fullScreenWidth - readSetting.imageSpace.value) / 2, double.infinity);
  }

  @override
  FittedSizes getImageFittedSize(Size imageSize) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(double.infinity, readPageState.displayRegionSize.height),
    );
  }
}
