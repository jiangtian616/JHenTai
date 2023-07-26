import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';

import '../../../../setting/read_setting.dart';
import '../base/base_layout_logic.dart';
import 'horizontal_double_column_layout_state.dart';

class HorizontalDoubleColumnLayoutLogic extends BaseLayoutLogic {
  HorizontalDoubleColumnLayoutState state = HorizontalDoubleColumnLayoutState();

  final StorageService storageService = Get.find<StorageService>();

  Worker? displayFirstPageAloneListener;

  @override
  void onInit() {
    super.onInit();

    List<bool>? cachedIsSpreadPage = storageService.read('isSpreadPage::${readPageState.readPageInfo.gid}')?.cast<bool>();
    if (cachedIsSpreadPage != null && cachedIsSpreadPage.length == readPageState.readPageInfo.pageCount) {
      state.isSpreadPage = cachedIsSpreadPage;
    } else {
      state.isSpreadPage = List.generate(readPageState.readPageInfo.pageCount, (_) => false);
    }

    state.pageCount = computePageCount();

    state.pageController = PageController(initialPage: computePageIndexOfImage(readPageState.readPageInfo.initialIndex));

    /// record reading progress and sync thumbnails list index
    state.pageController.addListener(_readProgressListener);

    displayFirstPageAloneListener = ever(ReadSetting.displayFirstPageAlone, (value) {
      if (state.displayFirstPageAlone != value) {
        state.displayFirstPageAlone = value;
        state.pageCount = computePageCount();
        updateSafely([BaseLayoutLogic.pageId]);
        readPageLogic.updateSafely([readPageLogic.topMenuId, readPageLogic.bottomMenuId]);
      }
    });
  }

  @override
  void onClose() {
    super.onClose();
    displayFirstPageAloneListener?.dispose();
  }

  @override
  void toLeft() {
    if (ReadSetting.isInRight2LeftDirection) {
      toNext();
    } else {
      toPrev();
    }
  }

  @override
  void toRight() {
    if (ReadSetting.isInRight2LeftDirection) {
      toPrev();
    } else {
      toNext();
    }
  }

  @override
  void toPrev() {
    int currentPage = state.pageController.page!.toInt();
    if (currentPage <= 0) {
      return;
    }

    int targetIndex = computeImagesInPageIndex(currentPage - 1).first;
    toImageIndex(targetIndex);
  }

  @override
  void toNext() {
    int currentPage = state.pageController.page!.toInt();
    if (currentPage >= state.pageCount - 1) {
      return;
    }

    int targetIndex = computeImagesInPageIndex(currentPage + 1).first;
    toImageIndex(targetIndex);
  }

  @override
  void handleM() {
    toggleDisplayFirstPageAlone();
  }

  @override
  void jump2ImageIndex(int imageIndex) {
    state.pageController.jumpToPage(computePageIndexOfImage(imageIndex));
    super.jump2ImageIndex(imageIndex);
  }

  @override
  void scroll2ImageIndex(int imageIndex, [Duration? duration]) {
    state.pageController.animateToPage(
      computePageIndexOfImage(imageIndex),
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(imageIndex, duration);
  }

  @override
  void enterAutoMode() {
    _enterAutoModeByTurnPage();
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (ReadSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read direction
        if (!ReadSetting.isInDoubleColumnReadDirection) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        /// stop when at last
        if (state.pageController.page!.toInt() == state.pageCount - 1) {
          Get.engine.addPostFrameCallback((_) {
            readPageLogic.closeAutoMode();
          });
          autoModeTimer?.cancel();
          return;
        }

        toNext();
      },
    );
  }

  void _readProgressListener() {
    int currentPage = state.pageController.page!.toInt();
    List<int> imageIndexes = computeImagesInPageIndex(currentPage);
    readPageLogic.recordReadProgress(imageIndexes.first);
    readPageLogic.syncThumbnails(imageIndexes.first);
  }

  @override
  Size getPlaceHolderSize(int imageIndex) {
    if (readPageState.imageContainerSizes[imageIndex] != null) {
      return readPageState.imageContainerSizes[imageIndex]!;
    }
    return Size((fullScreenWidth - ReadSetting.imageSpace.value) / 2, double.infinity);
  }

  FittedSizes getImageFittedSizeIncludeSpread(Size imageSize, bool isSpreadPage) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(isSpreadPage ? fullScreenWidth : (fullScreenWidth - ReadSetting.imageSpace.value) / 2, screenHeight),
    );
  }

  void updateSpreadPage(int imageIndex) {
    /// has recognized from cache
    if (state.isSpreadPage[imageIndex]) {
      galleryDownloadService.updateSafely(['${galleryDownloadService.downloadImageId}::${readPageState.readPageInfo.gid}::$imageIndex']);
      return;
    }

    state.isSpreadPage[imageIndex] = true;
    state.pageCount = computePageCount();

    updateSafely([BaseLayoutLogic.pageId]);
    if (computePageIndexOfImage(imageIndex) <= state.pageController.page!.toInt()) {
      jump2ImageIndex(readPageState.readPageInfo.currentImageIndex);
    }
    storageService.write('isSpreadPage::${readPageState.readPageInfo.gid}', state.isSpreadPage);
  }

  int computePageCount() {
    return computePageIndexOfImage(state.isSpreadPage.length - 1) + 1;
  }

  /// provide a page index, compute which images we should display in this page
  List<int> computeImagesInPageIndex(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= state.pageCount) {
      return [];
    }

    int currentImageIndex = 0;
    int currentPageIndex = 0;
    bool hasLeftColumn = false;

    if (state.displayFirstPageAlone) {
      if (pageIndex == 0) {
        return [0];
      }
      currentImageIndex++;
      currentPageIndex++;
    }

    while (currentPageIndex < pageIndex) {
      bool isSpreadPage = state.isSpreadPage[currentImageIndex];

      if (isSpreadPage && !hasLeftColumn) {
        currentImageIndex++;
        currentPageIndex++;
        continue;
      }

      if (isSpreadPage && hasLeftColumn) {
        currentImageIndex++;
        currentPageIndex += 2;
        hasLeftColumn = false;
        continue;
      }

      if (hasLeftColumn) {
        currentImageIndex++;
        currentPageIndex++;
        hasLeftColumn = false;
        continue;
      }

      currentImageIndex++;
      hasLeftColumn = true;
    }

    if (currentPageIndex > pageIndex) {
      return [currentImageIndex - 1];
    }

    if (state.isSpreadPage[currentImageIndex]) {
      return [currentImageIndex];
    }

    if (currentImageIndex == state.isSpreadPage.length - 1) {
      return [currentImageIndex];
    }

    if (state.isSpreadPage[currentImageIndex + 1]) {
      return [currentImageIndex];
    }

    return [currentImageIndex, currentImageIndex + 1];
  }

  /// provide a image index, compute we should display this image in which page
  int computePageIndexOfImage(int imageIndex) {
    int beginImageIndex = 0;
    int pageIndex = 0;
    bool hasLeftColumn = false;

    if (state.displayFirstPageAlone) {
      if (imageIndex == 0) {
        return 0;
      }
      beginImageIndex++;
      pageIndex++;
    }

    for (int i = beginImageIndex; i < imageIndex; i++) {
      bool isSpreadPage = state.isSpreadPage[i];

      if (isSpreadPage && !hasLeftColumn) {
        pageIndex++;
        continue;
      }

      if (isSpreadPage && hasLeftColumn) {
        pageIndex += 2;
        hasLeftColumn = false;
        continue;
      }

      if (hasLeftColumn) {
        pageIndex++;
        hasLeftColumn = false;
        continue;
      }

      hasLeftColumn = true;
    }

    if (state.isSpreadPage[imageIndex] && hasLeftColumn) {
      return pageIndex + 1;
    }

    return pageIndex;
  }

  void toggleDisplayFirstPageAlone() {
    Log.info('toggleDisplayFirstPageAlone->${!state.displayFirstPageAlone}');
    state.displayFirstPageAlone = !state.displayFirstPageAlone;
    state.pageCount = computePageCount();
    updateSafely([BaseLayoutLogic.pageId]);
    readPageLogic.updateSafely([readPageLogic.topMenuId, readPageLogic.bottomMenuId]);
  }
}
