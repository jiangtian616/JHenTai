import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
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
    return PhotoViewGallery.builder(
      itemCount: readPageState.readPageInfo.pageCount,
      scrollPhysics: const ClampingScrollPhysics(),
      pageController: logic.pageController,
      cacheExtent: ReadSetting.preloadPageCount.value.toDouble(),
      reverse: ReadSetting.isInRight2LeftDirection,
      builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
        initialScale: 1.0,
        minScale: 1.0,
        maxScale: 2.5,
        scaleStateCycle: ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.scaleStateCycle : null,
        enableTapDragZoom: ReadSetting.enableTapDragToScaleUp.isTrue,
        child: readPageState.readPageInfo.mode == ReadMode.online ? buildItemInOnlineMode(context, index) : buildItemInLocalMode(context, index),
      ),
    );
  }
}
