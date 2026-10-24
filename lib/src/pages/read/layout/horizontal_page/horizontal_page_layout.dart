import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/widget/eh_swipe_page_turner.dart';
import 'package:jhentai/src/widget/eh_wheel_scroll_listener.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../setting/read_setting.dart';
import '../base/base_layout.dart';
import 'horizontal_page_layout_logic.dart';
import 'horizontal_page_layout_state.dart';

class HorizontalPageLayout extends BaseLayout {
  HorizontalPageLayout({Key? key}) : super(key: key);

  @override
  final HorizontalPageLayoutLogic logic = Get.put<HorizontalPageLayoutLogic>(HorizontalPageLayoutLogic(), permanent: true);

  final HorizontalPageLayoutState state = Get.find<HorizontalPageLayoutLogic>().state;

  @override
  Widget buildBody(BuildContext context) {
    /// with swipe animation off, a swipe should switch page immediately instead of dragging the page
    bool instantTurnPage = readSetting.instantSwipeTurnPage;

    Widget body = EHWheelListener(
      onPointerScroll: logic.readPageLogic.isInFitWidthReadDirection ? null : logic.onPointerScroll,
      child: PhotoViewGallery.builder(
        enableCtrlScrollZoom: true,
        itemCount: readPageState.readPageInfo.pageCount,
        scrollPhysics: instantTurnPage ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        scaleStateChangedCallback: (scaleState) => state.isZoomed = scaleState != PhotoViewScaleState.initial,
        onPageChanged: (_) => state.isZoomed = false,
        pageController: logic.pageController,
        cacheExtent: readPageState.readPageInfo.mode == ReadMode.online
            ? readSetting.preloadPageCount.value.toDouble()
            : readSetting.preloadPageCountLocal.value.toDouble(),
        reverse: logic.readPageLogic.isInRight2LeftDirection,
        builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
          initialScale: 1.0,
          minScale: 1.0,
          maxScale: 2.5,
          scaleStateCycle: readSetting.enableDoubleTapToScaleUp.isTrue ? logic.scaleStateCycle : null,
          enableTapDragZoom: readSetting.enableTapDragToScaleUp.isTrue,
          child: Obx(() {
            Widget item = readPageState.readPageInfo.mode == ReadMode.online ? buildItemInOnlineMode(context, index) : buildItemInLocalMode(context, index);

            if (logic.readPageLogic.isInFitWidthReadDirection) {
              item = Center(child: SingleChildScrollView(controller: ScrollController(), child: item));
            }

            return item;
          }),
        ),
      ),
    );

    return EHSwipePageTurner(
      enabled: instantTurnPage,
      canSwipe: () => !state.isZoomed,
      onSwipeLeft: logic.toRight,
      onSwipeRight: logic.toLeft,
      child: body,
    );
  }
}
