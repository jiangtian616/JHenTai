import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:photo_view/photo_view.dart';

import '../base/base_layout_logic.dart';
import 'horizontal_page_layout_state.dart';

class HorizontalPageLayoutLogic extends BaseLayoutLogic {
  HorizontalPageLayoutState state = HorizontalPageLayoutState();

  late PageController pageController;

  @override
  void onInit() {
    super.onInit();

    state.photoViewControllers = List.generate(readPageState.readPageInfo.pageCount, (index) => PhotoViewController());

    pageController = PageController(initialPage: readPageState.readPageInfo.currentIndex);

    /// record reading progress and sync thumbnails list index
    pageController.addListener(_readProgressListener);
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

  @override
  void toPrev() {
    int targetIndex = (pageController.page! - 1).toInt();
    toPageIndex(max(targetIndex, 0));
  }

  @override
  void toNext() {
    int targetIndex = (pageController.page! + 1).toInt();
    toPageIndex(min(targetIndex, readPageState.readPageInfo.pageCount));
  }

  @override
  void jump2PageIndex(int pageIndex) {
    pageController.jumpToPage(pageIndex);
    super.jump2PageIndex(pageIndex);
  }

  @override
  void scroll2PageIndex(int pageIndex, [Duration? duration]) {
    pageController.animateToPage(
      pageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2PageIndex(pageIndex, duration);
  }

  @override
  void enterAutoMode() {
    _enterAutoModeByTurnPage();
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (ReadSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read setting
        if (ReadSetting.readDirection.value == ReadDirection.top2bottom ||
            ReadSetting.enableContinuousHorizontalScroll.isTrue ||
            ReadSetting.enableDoubleColumn.isTrue) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// stop when at last
        if (readPageState.readPageInfo.currentIndex == readPageState.readPageInfo.pageCount - 1) {
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

  void _readProgressListener() {
    int currentPage = pageController.page!.toInt();
    readPageLogic.recordReadProgress(currentPage);
    readPageLogic.syncThumbnails(currentPage);
  }
}
