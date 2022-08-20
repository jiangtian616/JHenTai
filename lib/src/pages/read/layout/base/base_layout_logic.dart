import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import '../../../../model/gallery_image.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/screen_size_util.dart';
import '../../read_page_logic.dart';
import '../../read_page_state.dart';
import 'base_layout_state.dart';

abstract class BaseLayoutLogic extends GetxController {
  BaseLayoutState get state;

  final ReadPageLogic readPageLogic = Get.find<ReadPageLogic>();
  final ReadPageState readPageState = Get.find<ReadPageLogic>().state;

  Timer? autoModeTimer;

  @override
  void onClose() {
    autoModeTimer?.cancel();
    super.onClose();
  }

  /// Tap left region or click right arrow key. If read direction is right-to-left, we should call [toNext], otherwise [toPrev]
  void toLeft();

  /// Tap right region or click right arrow key. If read direction is right-to-left, we should call [toPrev], otherwise [toNext]
  void toRight();

  /// to prev image or screen
  void toPrev();

  /// to next image or screen
  void toNext();

  void toPageIndex(int pageIndex) {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      jump2PageIndex(pageIndex);
    } else {
      scroll2PageIndex(pageIndex);
    }
  }

  @mustCallSuper
  void scroll2PageIndex(int pageIndex, [Duration? duration]) {
    readPageLogic.update([readPageLogic.sliderId]);
  }

  @mustCallSuper
  void jump2PageIndex(int pageIndex) {
    readPageLogic.update([readPageLogic.sliderId]);
  }

  void onScaleEnd(BuildContext context, ScaleEndDetails details, PhotoViewControllerValue controllerValue) {
    if (controllerValue.scale! < 1) {
      state.photoViewScaleStateController.reset();
    }
  }

  void enterAutoMode();

  /// Compute image container size

  @mustCallSuper
  void closeAutoMode() {
    autoModeTimer?.cancel();
  }

  Size getPlaceHolderSize() {
    return Size(double.infinity, screenHeight / 2);
  }

  FittedSizes getImageFittedSize(GalleryImage image) {
    return applyBoxFit(
      BoxFit.contain,
      Size(image.width, image.height),
      Size(fullScreenWidth, double.infinity),
    );
  }
}
