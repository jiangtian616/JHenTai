import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/read/layout/vertical_list/vertical_list_layout_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../base/base_layout_logic.dart';
import '../base/list_layout_logic.dart';

class VerticalListLayoutLogic extends BaseLayoutLogic with ListLayoutLogic {
  final String verticalLayoutId = 'verticalLayoutId';

  VerticalListLayoutState state = VerticalListLayoutState();

  late Worker imageRegionWidthRatioListener;
  late Worker portraitImageRegionWidthRatioListener;
  late Worker landscapeImageRegionWidthRatioListener;

  @override
  ItemPositionsListener get itemPositionsListener => state.itemPositionsListener;

  @override
  ItemScrollController get itemScrollController => state.itemScrollController;

  @override
  ScrollOffsetController get scrollOffsetController => state.scrollOffsetController;

  @override
  double get screenTurnOffset =>
      screenHeight - Get.mediaQuery.padding.bottom - (readSetting.enableImmersiveMode.isTrue ? 0 : Get.mediaQuery.padding.top);

  @override
  bool get isActiveListReadDirection => readPageLogic.effectiveReadDirection == ReadDirection.top2bottomList;

  void _onImageRegionWidthRatioChanged(int value) {
    readPageLogic.clearImageContainerSized();
    updateSafely([verticalLayoutId]);
  }

  @override
  void onReady() {
    super.onReady();

    imageRegionWidthRatioListener = ever(readSetting.imageRegionWidthRatio, _onImageRegionWidthRatioChanged);
    portraitImageRegionWidthRatioListener = ever(readSetting.portraitImageRegionWidthRatio, _onImageRegionWidthRatioChanged);
    landscapeImageRegionWidthRatioListener = ever(readSetting.landscapeImageRegionWidthRatio, _onImageRegionWidthRatioChanged);
  }

  @override
  void onClose() {
    super.onClose();

    imageRegionWidthRatioListener.dispose();
    portraitImageRegionWidthRatioListener.dispose();
    landscapeImageRegionWidthRatioListener.dispose();
  }

  @override
  void toLeft() {
    toPrev();
  }

  @override
  void toRight() {
    toNext();
  }

  @override
  void jump2ImageIndex(int imageIndex) {
    /// Method [jumpTo] leads to redrawing, so wo use scrollTo
    itemScrollController.scrollTo(index: imageIndex, duration: const Duration(milliseconds: 1));
    super.jump2ImageIndex(imageIndex);
  }

  @override
  void toNextImage() {
    ItemPosition? lastPosition = getCurrentVisibleItems().lastOrNull;
    if (lastPosition == null) {
      return;
    }

    int targetIndex = (lastPosition.itemLeadingEdge > 0 && lastPosition.itemTrailingEdge > 1) ? lastPosition.index : lastPosition.index + 1;
    toImageIndex(min(targetIndex, readPageState.readPageInfo.pageCount - 1));
  }

  @override
  Size getPlaceHolderSize(int imageIndex) {
    if (readPageState.imageContainerSizes[imageIndex] != null) {
      return readPageState.imageContainerSizes[imageIndex]!;
    }
    return Size(readPageState.displayRegionSize.width * readPageLogic.effectiveImageRegionWidthRatio / 100, readPageState.displayRegionSize.height / 2);
  }

  @override
  FittedSizes getImageFittedSize(Size imageSize) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(readPageState.displayRegionSize.width * readPageLogic.effectiveImageRegionWidthRatio / 100, double.infinity),
    );
  }
}
