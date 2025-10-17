import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import '../../../../service/ml_tts_service.dart';
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

  @override
  Future<void> toPrev() async {
    int targetIndex = (pageController.page! - 1).toInt();
    int index = max(targetIndex, 0);
    toImageIndex(index);
    if (targetIndex == index) {
      _play(index);
    }
  }

  @override
  void toNext() async {
    int targetIndex = (pageController.page! + 1).toInt();
    int index = min(targetIndex, readPageState.readPageInfo.pageCount - 1);
    toImageIndex(index);
    if (targetIndex == index) {
      _play(index);
    }
  }

  @override
  void jump2ImageIndex(int pageIndex) async {
    pageController.jumpToPage(pageIndex);
    super.jump2ImageIndex(pageIndex);
    _play(pageIndex);
  }

  @override
  void scroll2ImageIndex(int pageIndex, [Duration? duration]) {
    pageController.animateToPage(
      pageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(pageIndex, duration);
    _play(pageIndex);
  }

  @override
  void enterAutoMode() {
    _enterAutoModeByTurnPage();
  }

  void _play(int index) async {
    String? path = await readPageState.images[index]?.getValidAbsolutePath();
    mlTtsService.playFromPath(path);
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (readSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read setting
        if (!readSetting.isInSinglePageReadDirection) {
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

        if (!mlTtsService.isPlaying) {
          toNext();
        }
      },
    );
  }

  void _readProgressListener() {
    int currentPage = pageController.page!.toInt();
    readPageLogic.recordReadProgress(currentPage);
    readPageLogic.syncThumbnails(currentPage);
  }
}
