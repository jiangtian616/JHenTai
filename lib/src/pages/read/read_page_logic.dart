import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/pages/read/layout/base/base_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_double_column/horizontal_double_column_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_list/horizontal_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/horizontal_page/horizontal_page_layout_logic.dart';
import 'package:jhentai/src/pages/read/layout/vertical_list/vertical_list_layout_logic.dart';
import 'package:jhentai/src/pages/read/read_page_state.dart';
import 'package:jhentai/src/service/volume_service.dart';
import 'package:retry/retry.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:throttling/throttling.dart';

import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../network/eh_request.dart';
import '../../utils/check_util.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../../widget/auto_mode_interval_dialog.dart';
import '../../widget/loading_state_indicator.dart';
import '../details/details_page_logic.dart';

class ReadPageLogic extends GetxController {
  final String onlineImageId = 'onlineImageId';
  final String parseImageHrefsStateId = 'parseImageHrefsStateId';
  final String parseImageUrlStateId = 'parseImageUrlStateId';
  final String autoModeId = 'autoModeId';
  final String batteryId = 'batteryId';
  final String currentTimeId = 'currentTimeId';
  final String topMenuId = 'topMenuId';
  final String bottomMenuId = 'bottomMenuId';
  final String rightBottomInfoId = 'rightBottomInfoId';
  final String pageNoId = 'pageNoId';
  final String thumbnailNoId = 'thumbnailsId';
  final String sliderId = 'sliderId';

  ReadPageState state = ReadPageState();

  BaseLayoutLogic get layoutLogic => ReadSetting.readDirection.value == ReadDirection.top2bottom
      ? Get.find<VerticalListLayoutLogic>()
      : ReadSetting.enableContinuousHorizontalScroll.isTrue
          ? Get.find<HorizontalListLayoutLogic>()
          : ReadSetting.enableDoubleColumn.isTrue
              ? Get.find<HorizontalDoubleColumnLayoutLogic>()
              : Get.find<HorizontalPageLayoutLogic>();

  final StorageService storageService = Get.find();
  final VolumeService volumeService = Get.find();

  late Timer refreshCurrentTimeAndBatteryLevelTimer;
  late Worker toggleCurrentImmersiveModeLister;

  final Throttling _thr = Throttling(duration: const Duration(milliseconds: 200));

  @override
  void onReady() {
    super.onReady();

    /// Turn page by volume keys. The reason for not use [KeyboardListener]: https://github.com/flutter/flutter/issues/71144
    volumeService.listen((VolumeEventType type) {
      if (type == VolumeEventType.volumeUp) {
        layoutLogic.toPrev();
      } else if (type == VolumeEventType.volumeDown) {
        layoutLogic.toNext();
      }
    });
    volumeService.setInterceptVolumeEvent(true);

    toggleCurrentImmersiveMode();

    /// Listen to change
    toggleCurrentImmersiveModeLister = ever(ReadSetting.enableImmersiveMode, (_) => toggleCurrentImmersiveMode());

    if (!GetPlatform.isDesktop) {
      state.battery.batteryLevel.then((value) => state.batteryLevel = value);
    }

    /// refresh current time and battery level info
    refreshCurrentTimeAndBatteryLevelTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!GetPlatform.isDesktop) {
          state.battery.batteryLevel.then((value) {
            state.batteryLevel = value;
            update([batteryId]);
          });
        }
        update([currentTimeId]);
      },
    );
  }

  @override
  void onClose() {
    super.onClose();

    state.focusNode.dispose();
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    toggleCurrentImmersiveModeLister.dispose();

    volumeService.cancelListen();
    volumeService.setInterceptVolumeEvent(false);

    restoreSystemBar();

    storageService.write(state.readPageInfo.readProgressRecordStorageKey, state.readPageInfo.currentIndex);

    /// update read progress in detail page
    DetailsPageLogic.current?.update();

    Get.delete<VerticalListLayoutLogic>(force: true);
    Get.delete<HorizontalListLayoutLogic>(force: true);
    Get.delete<HorizontalPageLayoutLogic>(force: true);
    Get.delete<HorizontalDoubleColumnLayoutLogic>(force: true);
  }

  void beginToParseImageHref(int index) {
    if (state.parseImageHrefsStates[index] == LoadingState.loading) {
      return;
    }

    state.parseImageHrefsStates[index] = LoadingState.loading;
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _parseImageHref(index);
    });
  }

  Future<void> _parseImageHref(int index) async {
    Log.verbose('Begin to load Thumbnail $index', false);
    update([parseImageHrefsStateId]);

    Map<String, dynamic> rangeAndThumbnails;
    try {
      rangeAndThumbnails = await retry(
        () => EHRequest.requestDetailPage(
          galleryUrl: state.readPageInfo.galleryUrl!,
          thumbnailsPageIndex: index ~/ state.thumbnailsCountPerPage,
          parser: EHSpiderParser.detailPage2RangeAndThumbnails,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioError && e.error is! EHException,
        onRetry: (e) => Log.error('Get thumbnails error!', (e as DioError).message),
      );
    } on DioError catch (e) {
      if (e.error is EHException) {
        state.parseImageHrefErrorMsg = e.error.msg;
      } else {
        state.parseImageHrefErrorMsg = 'parsePageFailed'.tr;
      }
      state.parseImageHrefsStates[index] = LoadingState.error;
      update([parseImageHrefsStateId]);
      return;
    }

    int rangeFrom = rangeAndThumbnails['rangeIndexFrom'];
    int rangeTo = rangeAndThumbnails['rangeIndexTo'];
    List<GalleryThumbnail> newThumbnails = rangeAndThumbnails['thumbnails'];

    /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
    /// For example, default setting is 40, but some gallerys' thumbnails has only high quality thumbnails, which results in 20.
    state.thumbnailsCountPerPage = (newThumbnails.length / 20).ceil() * 20;

    state.parseImageHrefsStates[index] = LoadingState.idle;
    for (int i = rangeFrom; i <= rangeTo; i++) {
      state.thumbnails[i] = newThumbnails[i - rangeFrom];
      update(['$onlineImageId::$i']);
    }

    /// if gallery's [thumbnailsCountPerPage] is not equal to default setting, we probably can't get target thumbnails this turn
    /// because the [thumbnailsPageIndex] we computed before is wrong, so we need to parse again
    if (state.thumbnails[index] == null) {
      return _parseImageHref(index);
    }
  }

  void beginToParseImageUrl(int index, bool reParse) {
    if (state.parseImageUrlStates[index] == LoadingState.loading) {
      return;
    }
    state.parseImageUrlStates[index] = LoadingState.loading;
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _parseImageUrl(index, reParse);
    });
  }

  Future<void> _parseImageUrl(int index, bool reParse) async {
    update(['$parseImageUrlStateId::$index']);

    GalleryImage image;
    try {
      image = await retry(
        () => EHRequest.requestImagePage(
          state.thumbnails[index]!.href,
          parser: EHSpiderParser.imagePage2GalleryImage,
          useCacheIfAvailable: !reParse,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioError && e.error is! EHException,
        onRetry: (e) => Log.error('Parse gallery image failed, index: ${index.toString()}', (e as DioError).message),
      );
    } on DioError catch (e) {
      state.parseImageUrlStates[index] = LoadingState.error;
      if (e.error is EHException) {
        state.parseImageUrlErrorMsg[index] = e.error.msg;
      } else {
        state.parseImageUrlErrorMsg[index] = 'parseURLFailed'.tr;
      }
      update(['$parseImageUrlStateId::$index']);
      return;
    }

    state.images[index] = image;
    state.parseImageUrlStates[index] = LoadingState.success;
    update(['$onlineImageId::$index']);
  }

  /// If [enableImmersiveMode], switch to [SystemUiMode.immersiveSticky], otherwise reset to [SystemUiMode.edgeToEdge]
  void toggleCurrentImmersiveMode() {
    if (ReadSetting.enableImmersiveMode.isTrue) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void restoreSystemBar() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// double tap to scale up or reset
  void toggleScale(Offset position) {
    layoutLogic.toggleScale(position);
  }

  void toggleMenu() {
    state.isMenuOpen = !state.isMenuOpen;
    update([topMenuId, bottomMenuId, rightBottomInfoId]);
  }

  Future<void> toggleAutoMode() async {
    if (state.autoMode) {
      return closeAutoMode();
    }

    bool? begin = await Get.dialog(const AutoModeIntervalDialog());
    if (begin == null || !begin) {
      return;
    }

    enterAutoMode();
  }

  void enterAutoMode() {
    state.autoMode = true;
    update([autoModeId]);
    layoutLogic.enterAutoMode();
  }

  void closeAutoMode() {
    state.autoMode = false;
    update([autoModeId]);
    layoutLogic.closeAutoMode();
  }

  /// Tap left region or click right arrow key. If read direction is right-to-left, we should call [toNext], otherwise [toPrev]
  void toLeft() {
    layoutLogic.toLeft();
  }

  /// Tap right region or click right arrow key. If read direction is right-to-left, we should call [toPrev], otherwise [toNext]
  void toRight() {
    layoutLogic.toRight();
  }

  /// to prev image or screen
  void toPrev() {
    layoutLogic.toPrev();
  }

  /// to next image or screen
  void toNext() {
    layoutLogic.toNext();
  }

  void jump2PageIndex(int pageIndex) {
    layoutLogic.jump2PageIndex(pageIndex);
  }

  void handleSlide(double pageNo) {
    state.readPageInfo.currentIndex = (pageNo - 1).toInt();
    update([sliderId, pageNoId]);
  }

  void handleSlideEnd(double pageNo) {
    jump2PageIndex((pageNo - 1).toInt());
  }

  /// Sync thumbnails after user scrolling to image whose index is [targetImageIndex]
  void syncThumbnails(int targetImageIndex) {
    if (ReadSetting.showThumbnails.isFalse) {
      return;
    }

    int? firstThumbnailIndex = getCurrentVisibleThumbnails().firstOrNull?.index;
    int? lastThumbnailIndex = getCurrentVisibleThumbnails().lastOrNull?.index;
    if (firstThumbnailIndex == null) {
      return;
    }

    /// No more thumbnails, do not scroll more
    if (lastThumbnailIndex == state.readPageInfo.pageCount - 1 && targetImageIndex > firstThumbnailIndex) {
      return;
    }

    /// If a new scroll starts before previous scroll end, the previous scroll will be cancelled. So if user keeps scrolling
    /// the list, the scroll of the thumbnail list will be delayed until the user stops scrolling. We use Throttling to avoid.
    _thr.throttle(() {
      scrollThumbnailsToIndex(targetImageIndex);
    });
  }

  void jumpThumbnailsToIndex(int index) {
    state.thumbnailsScrollController.jumpTo(
      index: max(0, index - 2),
    );
  }

  void scrollThumbnailsToIndex(int index) {
    state.thumbnailsScrollController.scrollTo(
      index: max(0, index - 2),
      duration: const Duration(milliseconds: 200),
    );
  }

  List<ItemPosition> getCurrentVisibleThumbnails() {
    return filterAndSortItems(state.thumbnailPositionsListener.itemPositions.value);
  }

  /// for some reason like slow loading of some image, [ItemPositions] may be not in index order, and even some of
  /// them are not in viewport
  List<ItemPosition> filterAndSortItems(Iterable<ItemPosition> positions) {
    positions = positions.where((item) => !(item.itemTrailingEdge < 0 || item.itemLeadingEdge > 1)).toList();
    (positions as List<ItemPosition>).sort((a, b) => a.index - b.index);
    return positions;
  }

  void recordReadProgress(int index) {
    state.readPageInfo.currentIndex = index;
    update([sliderId, pageNoId, thumbnailNoId]);
  }
}
