import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/service/ml_tts_service.dart';
import 'package:jhentai/src/widget/eh_wheel_scroll_listener.dart';
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
    return EHWheelListener(
      onPointerScroll: readSetting.isInFitWidthReadDirection ? null : logic.onPointerScroll,
      child: PhotoViewGallery.builder(
        itemCount: readPageState.readPageInfo.pageCount,
        scrollPhysics: const ClampingScrollPhysics(),
        pageController: logic.pageController,
        cacheExtent: readPageState.readPageInfo.mode == ReadMode.online
            ? readSetting.preloadPageCount.value.toDouble()
            : readSetting.preloadPageCountLocal.value.toDouble(),
        reverse: readSetting.isInRight2LeftDirection,
        builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
          initialScale: 1.0,
          minScale: 1.0,
          maxScale: 2.5,
          scaleStateCycle: readSetting.enableDoubleTapToScaleUp.isTrue ? logic.scaleStateCycle : null,
          enableTapDragZoom: readSetting.enableTapDragToScaleUp.isTrue,
          child: Obx(() {
            final speakingTextBlock = mlTtsService.currentSpeakingTextBlock.value;
            Widget item = readPageState.readPageInfo.mode == ReadMode.online
                ? buildItemInOnlineMode(context, index, textBlock: speakingTextBlock)
                : buildItemInLocalMode(context, index, textBlock: speakingTextBlock);

            if (readSetting.isInFitWidthReadDirection) {
              item = Center(child: SingleChildScrollView(controller: ScrollController(), child: item));
            }

            return item;
          }),
        ),
      ),
    );
  }
}
