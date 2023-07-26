import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout_state.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../model/read_page_info.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../../../../widget/eh_wheel_speed_controller_for_read_page.dart';
import '../../widget/eh_scrollable_positioned_list.dart';
import '../base/base_layout.dart';
import 'horizontal_list_layout_logic.dart';

class HorizontalListLayout extends BaseLayout {
  HorizontalListLayout({Key? key}) : super(key: key);

  @override
  final HorizontalListLayoutLogic logic = Get.put<HorizontalListLayoutLogic>(HorizontalListLayoutLogic(), permanent: true);

  final HorizontalListLayoutState state = Get.find<HorizontalListLayoutLogic>().state;

  @override
  Widget buildBody(BuildContext context) {
    /// user PhotoViewGallery to scale up the whole gallery list, so set itemCount to 1
    return PhotoViewGallery.builder(
      itemCount: 1,
      builder: (_, __) => PhotoViewGalleryPageOptions.customChild(
        controller: state.photoViewController,
        initialScale: 1.0,
        minScale: 1.0,
        maxScale: 2.5,
        scaleStateCycle: ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.scaleStateCycle : null,
        enableTapDragZoom: ReadSetting.enableTapDragToScaleUp.isTrue,
        child: EHWheelSpeedControllerForReadPage(
          scrollController: state.itemScrollController,
          child: EHScrollablePositionedList.separated(
            scrollDirection: Axis.horizontal,
            reverse: ReadSetting.isInRight2LeftDirection,
            physics: const ClampingScrollPhysics(),
            minCacheExtent: readPageState.readPageInfo.mode == ReadMode.online ? ReadSetting.preloadDistance * screenHeight * 1 : 3 * fullScreenWidth,
            initialScrollIndex: readPageState.readPageInfo.initialIndex,
            itemCount: readPageState.readPageInfo.pageCount,
            itemScrollController: state.itemScrollController,
            itemPositionsListener: state.itemPositionsListener,
            itemBuilder: (context, index) =>
                readPageState.readPageInfo.mode == ReadMode.online ? buildItemInOnlineMode(context, index) : buildItemInLocalMode(context, index),
            separatorBuilder: (_, __) => Obx(() => SizedBox(width: ReadSetting.imageSpace.value.toDouble())),
          ),
        ),
      ),
    );
  }
}
