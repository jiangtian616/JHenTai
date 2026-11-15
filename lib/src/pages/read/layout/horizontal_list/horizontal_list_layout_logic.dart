import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../base/base_layout_logic.dart';
import '../base/list_layout_logic.dart';
import 'horizontal_list_layout_state.dart';

class HorizontalListLayoutLogic extends BaseLayoutLogic with ListLayoutLogic {
  HorizontalListLayoutState state = HorizontalListLayoutState();

  @override
  ItemPositionsListener get itemPositionsListener => state.itemPositionsListener;

  @override
  ItemScrollController get itemScrollController => state.itemScrollController;

  @override
  ScrollOffsetController get scrollOffsetController => state.scrollOffsetController;

  @override
  double get screenTurnOffset => fullScreenWidth;

  @override
  bool get isActiveListReadDirection =>
      readPageLogic.effectiveReadDirection == ReadDirection.left2rightList || readPageLogic.effectiveReadDirection == ReadDirection.right2leftList;

  @override
  void jump2ImageIndex(int imageIndex) {
    super.jump2ImageIndex(imageIndex);

    /// Method [jumpTo] leads to redrawing, so wo use scrollTo
    itemScrollController.scrollTo(index: imageIndex, duration: const Duration(milliseconds: 1));
  }

  @override
  void toNextImage() {
    ItemPosition? firstPosition = getCurrentVisibleItems().firstOrNull;
    if (firstPosition == null) {
      return;
    }

    toImageIndex(min(firstPosition.index + 1, readPageState.readPageInfo.pageCount - 1));
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
