import 'package:flutter/cupertino.dart';

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
  void toPrev() {
    int currentPage = pageController.page!.toInt();
    if (currentPage <= 0) {
      return readPageLogic.handleTurnPageBeyondBoundary(false);
    }

    toImageIndex(currentPage - 1);
  }

  @override
  void toNext() {
    int currentPage = pageController.page!.toInt();
    if (currentPage >= readPageState.readPageInfo.pageCount - 1) {
      return readPageLogic.handleTurnPageBeyondBoundary(true);
    }

    toImageIndex(currentPage + 1);
  }

  @override
  void jump2ImageIndex(int imageIndex) {
    pageController.jumpToPage(imageIndex);
    super.jump2ImageIndex(imageIndex);
  }

  @override
  void scroll2ImageIndex(int imageIndex, [Duration? duration]) {
    pageController.animateToPage(
      imageIndex,
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(imageIndex, duration);
  }

  @override
  void enterAutoMode() {
    enterAutoModeByTurnPage(
      shouldStop: () =>
          !readPageLogic.isInSinglePageReadDirection || readPageState.readPageInfo.currentImageIndex == readPageState.readPageInfo.pageCount - 1,
    );
  }

  void _readProgressListener() {
    readPageLogic.recordReadProgress(pageController.page!.toInt());
  }
}
