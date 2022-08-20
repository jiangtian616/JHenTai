import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_state.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../setting/read_setting.dart';
import '../../widget/eh_photo_view_gallery.dart';
import '../base/base_layout.dart';
import 'horizontal_double_column_layout_logic.dart';

class HorizontalDoubleColumnLayout extends BaseLayout {
  HorizontalDoubleColumnLayout({Key? key}) : super(key: key);

  @override
  final HorizontalDoubleColumnLayoutLogic logic = Get.put<HorizontalDoubleColumnLayoutLogic>(HorizontalDoubleColumnLayoutLogic(), permanent: true);

  @override
  final HorizontalDoubleColumnLayoutState state = Get.find<HorizontalDoubleColumnLayoutLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EHPhotoViewGallery.builder(
        itemCount: (readPageState.readPageInfo.pageCount + 1) ~/ 2,
        scrollPhysics: const ClampingScrollPhysics(),
        pageController: logic.pageController,
        cacheExtent: (ReadSetting.preloadPageCount.value.toDouble() + 1) / 2,
        reverse: ReadSetting.readDirection.value == ReadDirection.right2left,
        builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
          scaleStateController: state.photoViewScaleStateController,
          onScaleEnd: logic.onScaleEnd,
          child: readPageState.readPageInfo.mode == ReadMode.online
              ? _buildDoubleColumnItemInOnlineMode(context, index)
              : _buildDoubleColumnItemInLocalMode(context, index),
        ),
      ),
    );
  }

  Widget _buildDoubleColumnItemInOnlineMode(BuildContext context, int pageIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ReadSetting.readDirection.value == ReadDirection.left2right) buildItemInOnlineMode(context, pageIndex * 2),
        if (ReadSetting.readDirection.value == ReadDirection.right2left && pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount)
          buildItemInOnlineMode(context, pageIndex * 2 + 1),
        if (pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount) const VerticalDivider(width: 6),
        if (ReadSetting.readDirection.value == ReadDirection.left2right && pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount)
          buildItemInOnlineMode(context, pageIndex * 2 + 1),
        if (ReadSetting.readDirection.value == ReadDirection.right2left) buildItemInOnlineMode(context, pageIndex * 2),
      ],
    );
  }

  Widget _buildDoubleColumnItemInLocalMode(BuildContext context, int pageIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ReadSetting.readDirection.value == ReadDirection.left2right) buildItemInLocalMode(context, pageIndex * 2),
        if (ReadSetting.readDirection.value == ReadDirection.right2left && pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount)
          buildItemInLocalMode(context, pageIndex * 2 + 1),
        if (pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount) const VerticalDivider(width: 6),
        if (ReadSetting.readDirection.value == ReadDirection.left2right && pageIndex * 2 + 1 < readPageState.readPageInfo.pageCount)
          buildItemInLocalMode(context, pageIndex * 2 + 1),
        if (ReadSetting.readDirection.value == ReadDirection.right2left) buildItemInLocalMode(context, pageIndex * 2),
      ],
    );
  }
}
