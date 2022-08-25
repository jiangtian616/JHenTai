import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../model/gallery_image.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../base/base_layout_logic.dart';
import 'horizontal_list_layout_state.dart';

class HorizontalListLayoutLogic extends BaseLayoutLogic {
  @override
  HorizontalListLayoutState state = HorizontalListLayoutState();

  @override
  void onInit() {
    super.onInit();

    /// record reading progress and sync thumbnails list index
    state.itemPositionsListener.itemPositions.addListener(_readProgressListener);
  }

  @override
  void toLeft() {
    if (ReadSetting.readDirection.value == ReadDirection.left2right) {
      toPrev();
    } else {
      toNext();
    }
  }

  @override
  void toRight() {
    if (ReadSetting.readDirection.value == ReadDirection.left2right) {
      toNext();
    } else {
      toPrev();
    }
  }

  /// to prev image or screen
  @override
  void toPrev() {
    switch (ReadSetting.turnPageMode.value) {
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
    switch (ReadSetting.turnPageMode.value) {
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
  void jump2PageIndex(int imageIndex) {
    /// Method [jumpTo] leads to redrawing, so wo use scrollTo
    state.itemScrollController.scrollTo(index: imageIndex, duration: const Duration(milliseconds: 1));
    super.jump2PageIndex(imageIndex);
  }

  /// scroll to a certain image
  @override
  void scroll2PageIndex(int imageIndex, [Duration? duration]) {
    state.itemScrollController.scrollTo(
      index: imageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
    );
    super.scroll2PageIndex(imageIndex, duration);
  }

  /// scroll or jump until one image in viewport currently reach top
  void _toPrevImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    int targetIndex = firstPosition.itemLeadingEdge < 0 ? firstPosition.index : firstPosition.index - 1;
    toPageIndex(max(targetIndex, 0));
  }

  /// scroll or jump until last image in viewport currently reach top
  void _toNextImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    toPageIndex(min(firstPosition.index + 1, readPageState.readPageInfo.pageCount));
  }

  void _toPrevScreen() {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      state.itemScrollController.scrollOffset(
        offset: -fullScreenWidth,
        duration: const Duration(milliseconds: 1),
      );
    } else {
      state.itemScrollController.scrollOffset(
        offset: -fullScreenWidth,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  void _toNextScreen() {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      state.itemScrollController.scrollOffset(
        offset: fullScreenWidth,
        duration: const Duration(milliseconds: 1),
      );
    } else {
      state.itemScrollController.scrollOffset(
        offset: fullScreenWidth,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void enterAutoMode() {
    if (ReadSetting.autoModeStyle.value == AutoModeStyle.scroll) {
      _enterAutoModeByScroll();
    } else {
      _enterAutoModeByTurnPage();
    }
  }

  void _enterAutoModeByScroll() {
    int restPageCount = readPageState.readPageInfo.pageCount - readPageState.readPageInfo.currentIndex - 1;
    double offset = restPageCount * screenHeight;
    double totalTime = restPageCount * ReadSetting.autoModeInterval.value;

    readPageLogic.toggleMenu();

    state.itemScrollController
        .scrollOffset(
          offset: offset,
          duration: Duration(milliseconds: (totalTime * 1000).toInt()),
        )
        .then((_) => readPageLogic.closeAutoMode());
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (ReadSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read setting
        if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isFalse) {
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
  Size getPlaceHolderSize() {
    /// 6 is the width of divider
    return Size((fullScreenWidth - 6) / 2, double.infinity);
  }

  @override
  FittedSizes getImageFittedSize(GalleryImage image) {
    return applyBoxFit(
      BoxFit.contain,
      Size(image.width, image.height),
      Size(double.infinity, screenHeight),
    );
  }
}
