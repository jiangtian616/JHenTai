import 'package:collection/collection.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_state.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../setting/read_setting.dart';
import '../../../../widget/cached_page_view.dart';
import '../base/base_layout.dart';
import 'horizontal_double_column_layout_logic.dart';

class HorizontalDoubleColumnLayout extends BaseLayout {
  HorizontalDoubleColumnLayout({Key? key}) : super(key: key);

  @override
  final HorizontalDoubleColumnLayoutLogic logic = Get.put<HorizontalDoubleColumnLayoutLogic>(HorizontalDoubleColumnLayoutLogic(), permanent: true);

  final HorizontalDoubleColumnLayoutState state = Get.find<HorizontalDoubleColumnLayoutLogic>().state;

  @override
  Widget buildBody(BuildContext context) {
    return CachedPageView.builder(
      physics: const ClampingScrollPhysics(),
      controller: state.pageController,
      cacheExtent: (ReadSetting.preloadPageCount.value.toDouble() + 1) / 2,
      reverse: ReadSetting.readDirection.value == ReadDirection.right2left,
      itemCount: state.pageCount,
      itemBuilder: (BuildContext context, int index) {
        if (index < 0 || index >= state.pageCount) {
          return null;
        }

        return PhotoView.customChild(
          key: ObjectKey(index),
          child: readPageState.readPageInfo.mode == ReadMode.online
              ? _buildDoubleColumnItemInOnlineMode(context, index)
              : _buildDoubleColumnItemInLocalMode(context, index),
          initialScale: 1.0,
          minScale: 1.0,
          maxScale: 2.5,
          scaleStateCycle: ReadSetting.enableDoubleTapToScaleUp.isTrue ? logic.scaleStateCycle : null,
          enableTapDragZoom: ReadSetting.enableTapDragToScaleUp.isTrue,
        );
      },
    );
  }

  Widget? _buildDoubleColumnItemInOnlineMode(BuildContext context, int pageIndex) {
    List<int> displayImageIndexes = logic.computeImagesInPageIndex(pageIndex);
    if (displayImageIndexes.isEmpty) {
      return null;
    }

    if (ReadSetting.readDirection.value == ReadDirection.right2left) {
      displayImageIndexes.reverseRange(0, displayImageIndexes.length);
    }

    if (displayImageIndexes.length == 1) {
      return Center(child: buildItemInOnlineMode(context, displayImageIndexes[0]));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        buildItemInOnlineMode(context, displayImageIndexes[0]),
        SizedBox(width: ReadSetting.imageSpace.value.toDouble()),
        buildItemInOnlineMode(context, displayImageIndexes[1]),
      ],
    );
  }

  Widget? _buildDoubleColumnItemInLocalMode(BuildContext context, int pageIndex) {
    List<int> displayImageIndexes = logic.computeImagesInPageIndex(pageIndex);
    if (displayImageIndexes.isEmpty) {
      return null;
    }

    if (ReadSetting.readDirection.value == ReadDirection.right2left) {
      displayImageIndexes.reverseRange(0, displayImageIndexes.length);
    }

    if (displayImageIndexes.length == 1) {
      return Center(child: buildItemInLocalMode(context, displayImageIndexes[0]));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        buildItemInLocalMode(context, displayImageIndexes[0]),
        SizedBox(width: ReadSetting.imageSpace.value.toDouble()),
        buildItemInLocalMode(context, displayImageIndexes[1]),
      ],
    );
  }

  @override
  Widget? completedWidgetBuilderCallBack(int index, ExtendedImageState state) {
    if (state.extendedImageInfo == null || logic.readPageState.imageContainerSizes[index] != null) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.extendedImageInfo == null || logic.readPageState.imageContainerSizes[index] != null) {
        return;
      }

      bool isSpreadPage = state.extendedImageInfo!.image.width > state.extendedImageInfo!.image.height;

      FittedSizes fittedSizes = logic.getImageFittedSizeIncludeSpread(
        Size(
          state.extendedImageInfo!.image.width.toDouble(),
          state.extendedImageInfo!.image.height.toDouble(),
        ),
        isSpreadPage,
      );
      logic.readPageState.imageContainerSizes[index] = fittedSizes.destination;

      if (isSpreadPage && !this.state.isSpreadPage[index]) {
        logic.updateSpreadPage(index);
      } else {
        logic.readPageLogic.updateSafely(['${readPageLogic.onlineImageId}::$index']);
      }
    });

    return null;
  }

  @override
  Widget? completedWidgetBuilderForLocalModeCallBack(int index, ExtendedImageState state) {
    if (state.extendedImageInfo == null || logic.readPageState.imageContainerSizes[index] != null) {
      return null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.extendedImageInfo == null || logic.readPageState.imageContainerSizes[index] != null) {
        return;
      }

      bool isSpreadPage = state.extendedImageInfo!.image.width > state.extendedImageInfo!.image.height;

      FittedSizes fittedSizes = logic.getImageFittedSizeIncludeSpread(
        Size(
          state.extendedImageInfo!.image.width.toDouble(),
          state.extendedImageInfo!.image.height.toDouble(),
        ),
        isSpreadPage,
      );
      logic.readPageState.imageContainerSizes[index] = fittedSizes.destination;

      if (isSpreadPage && !this.state.isSpreadPage[index]) {
        logic.updateSpreadPage(index);
      } else {
        logic.galleryDownloadService.updateSafely(['${logic.galleryDownloadService.downloadImageId}::${readPageState.readPageInfo.gid}::$index']);
      }
    });

    return null;
  }
}
