import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import '../base/base_layout_logic.dart';
import 'horizontal_page_layout_state.dart';

class HorizontalPageLayoutLogic extends BaseLayoutLogic {
  HorizontalPageLayoutState state = HorizontalPageLayoutState();

  late PageController pageController;

  @override
  void onInit() {
    super.onInit();

    pageController = PageController(initialPage: readPageState.readPageInfo.currentImageIndex);

    /// record reading progress and sync thumbnails list index
    pageController.addListener(_readProgressListener);
  }

  @override
  void toLeft() {
    if (ReadSetting.isInRight2LeftDirection) {
      toNext();
    } else {
      toPrev();
    }
  }

  @override
  void toRight() {
    if (ReadSetting.isInRight2LeftDirection) {
       toPrev();
    } else {
      toNext();
    }
  }

  @override
  void toPrev() {
    int targetIndex = (pageController.page! - 1).toInt();
    toImageIndex(max(targetIndex, 0));
  }

  @override
  void toNext() {
    int targetIndex = (pageController.page! + 1).toInt();
    toImageIndex(min(targetIndex, readPageState.readPageInfo.pageCount));
  }

  @override
  void jump2ImageIndex(int pageIndex) {
    pageController.jumpToPage(pageIndex);
    super.jump2ImageIndex(pageIndex);
  }

  @override
  void scroll2ImageIndex(int pageIndex, [Duration? duration]) {
    pageController.animateToPage(
      pageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(pageIndex, duration);
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
        if (!ReadSetting.isInSinglePageReadDirection) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// stop when at last
        if (readPageState.readPageInfo.currentImageIndex == readPageState.readPageInfo.pageCount - 1) {
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
