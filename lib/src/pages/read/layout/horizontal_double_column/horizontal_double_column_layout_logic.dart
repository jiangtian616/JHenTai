import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';

import '../../../../service/gallery_download_service.dart';
import '../../../../setting/read_setting.dart';
import '../base/base_layout_logic.dart';
import 'horizontal_double_column_layout_state.dart';

class HorizontalDoubleColumnLayoutLogic extends BaseLayoutLogic {
  HorizontalDoubleColumnLayoutState state = HorizontalDoubleColumnLayoutState();

  Completer<void> initCompleter = Completer<void>();

  @override
  Future<void> onInit() async {
    super.onInit();

    String? cacheString = await localConfigService.read(
      configKey: ConfigEnum.isSpreadPage,
      subConfigKey: readPageState.readPageInfo.readProgressRecordStorageKey,
    );
    if (cacheString == null) {
      state.isSpreadPage = List.generate(readPageState.readPageInfo.pageCount, (_) => false);
    } else {
      List list = jsonDecode(cacheString);
      state.isSpreadPage = list.map((e) => e == 1).toList();
    }
    state.isSpreadPageCompleter.complete();

    state.pageCount = computePageCount();

    state.pageController = PageController(initialPage: computePageIndexOfImage(readPageState.readPageInfo.initialIndex));

    /// record reading progress and sync thumbnails list index
    state.pageController.addListener(_readProgressListener);

    initCompleter.complete();
  }

  @override
  void toLeft() {
    if (readSetting.isInRight2LeftDirection) {
      toNext();
    } else {
      toPrev();
    }
  }

  @override
  void toRight() {
    if (readSetting.isInRight2LeftDirection) {
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
  Future<void> jump2ImageIndex(int imageIndex) async {
    await state.isSpreadPageCompleter.future;

    state.pageController.jumpToPage(computePageIndexOfImage(imageIndex));
    super.jump2ImageIndex(imageIndex);
  }

  @override
  Future<void> scroll2ImageIndex(int imageIndex, [Duration? duration]) async {
    await state.isSpreadPageCompleter.future;

    state.pageController.animateToPage(
      computePageIndexOfImage(imageIndex),
      duration: duration ?? const Duration(milliseconds: 200),
      curve: Curves.ease,
    );
    super.scroll2ImageIndex(imageIndex, duration);
  }

  @override
  Future<void> toggleDisplayFirstPageAlone() async {
    await state.isSpreadPageCompleter.future;

    state.pageCount = computePageCount();
    updateSafely([BaseLayoutLogic.pageId]);
  }

  @override
  void enterAutoMode() {
    _enterAutoModeByTurnPage();
  }

  void _enterAutoModeByTurnPage() {
    readPageLogic.toggleMenu();

    autoModeTimer = Timer.periodic(
      Duration(milliseconds: (readSetting.autoModeInterval.value * 1000).toInt()),
      (_) {
        /// changed read direction
        if (!readSetting.isInDoubleColumnReadDirection) {
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

  @override
  void onClose() {
    state.pageController.removeListener(_readProgressListener);
    state.pageController.dispose();
    super.onClose();
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
    return Size((fullScreenWidth - readSetting.imageSpace.value) / 2, double.infinity);
  }

  FittedSizes getImageFittedSizeIncludeSpread(Size imageSize, bool isSpreadPage) {
    return applyBoxFit(
      BoxFit.contain,
      Size(imageSize.width, imageSize.height),
      Size(
        isSpreadPage ? readPageState.displayRegionSize.width : (readPageState.displayRegionSize.width - readSetting.imageSpace.value) / 2,
        readPageState.displayRegionSize.height,
      ),
    );
  }

  Future<void> updateSpreadPage(int imageIndex) async {
    await state.isSpreadPageCompleter.future;

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

    await localConfigService.write(
      configKey: ConfigEnum.isSpreadPage,
      subConfigKey: readPageState.readPageInfo.gid.toString(),
      value: jsonEncode(state.isSpreadPage.map((e) => e ? 1 : 0).toList()),
    );
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

    if (readPageState.displayFirstPageAlone) {
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

    if (readPageState.displayFirstPageAlone) {
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
}
