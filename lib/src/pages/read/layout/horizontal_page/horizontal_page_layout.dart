import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../setting/read_setting.dart';
import '../../widget/eh_photo_view_gallery.dart';
import '../base/base_layout.dart';
import 'horizontal_page_layout_logic.dart';
import 'horizontal_page_layout_state.dart';

class HorizontalPageLayout extends BaseLayout {
  HorizontalPageLayout({Key? key}) : super(key: key);

  @override
  final HorizontalPageLayoutLogic logic = Get.put<HorizontalPageLayoutLogic>(HorizontalPageLayoutLogic(), permanent: true);

  @override
  final HorizontalPageLayoutState state = Get.find<HorizontalPageLayoutLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EHPhotoViewGallery.builder(
        itemCount: readPageState.readPageInfo.pageCount,
        scrollPhysics: const ClampingScrollPhysics(),
        pageController: logic.pageController,
        cacheExtent: ReadSetting.preloadPageCount.value.toDouble(),
        reverse: ReadSetting.readDirection.value == ReadDirection.right2left,
        builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
          scaleStateController: state.photoViewScaleStateController,
          onScaleEnd: logic.onScaleEnd,
          child: Obx(() {
            Widget item =
                readPageState.readPageInfo.mode == ReadMode.online ? buildItemInOnlineMode(context, index) : buildItemInLocalMode(context, index);

            if (ReadSetting.enableAutoScaleUp.isTrue) {
              item = Center(child: SingleChildScrollView(controller: ScrollController(), child: item));
            }

            return item;
          }),
        ),
      ),
    );
  }
}
