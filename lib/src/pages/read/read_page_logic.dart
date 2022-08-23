import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
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
import 'package:retry/retry.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:throttling/throttling.dart';

import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../network/eh_request.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../setting/site_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../../utils/screen_size_util.dart';
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
  final String thumbnailsId = 'thumbnailsId';
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

  late Timer refreshCurrentTimeAndBatteryLevelTimer;

  final Throttling _thr = Throttling(duration: const Duration(milliseconds: 200));

  @override
  void onReady() {
    toggleCurrentImmersiveMode();

    /// Listen to change
    ever(ReadSetting.enableImmersiveMode, (_) => toggleCurrentImmersiveMode());

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

    super.onReady();
  }

  @override
  void onClose() {
    refreshCurrentTimeAndBatteryLevelTimer.cancel();
    state.focusNode.dispose();

    storageService.write('readIndexRecord::${state.readPageInfo.gid}', state.readPageInfo.currentIndex);
    restoreSystemBar();

    /// update read progress in detail page
    DetailsPageLogic.current?.update([bodyId]);

    Get.delete<VerticalListLayoutLogic>(force: true);
    Get.delete<HorizontalListLayoutLogic>(force: true);
    Get.delete<HorizontalPageLayoutLogic>(force: true);
    Get.delete<HorizontalDoubleColumnLayoutLogic>(force: true);

    super.onClose();
  }

  void beginToParseImageHref(int index) {
    if (state.parseImageHrefsState == LoadingState.loading) {
      return;
    }

    state.parseImageHrefsState = LoadingState.loading;
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _parseImageHref(index);
    });
  }

  Future<void> _parseImageHref(int index) async {
    Log.verbose('begin to load Thumbnails from $index', false);
    update([parseImageHrefsStateId]);

    List<GalleryThumbnail> newThumbnails;
    try {
      newThumbnails = await retry(
        () async => await EHRequest.requestDetailPage(
          galleryUrl: state.readPageInfo.galleryUrl,
          thumbnailsPageIndex: index ~/ SiteSetting.thumbnailsCountPerPage.value,
          parser: EHSpiderParser.detailPage2Thumbnails,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioError && e.error is! EHException,
        onRetry: (e) => Log.error('get thumbnails error!', (e as DioError).message),
      );
    } on DioError catch (e) {
      if (e.error is EHException) {
        state.parseImageHrefErrorMsg = e.error.msg;
      } else {
        state.parseImageHrefErrorMsg = 'parsePageFailed'.tr;
      }
      state.parseImageHrefsState = LoadingState.error;
      update([parseImageHrefsStateId]);
      return;
    }

    int from = index ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
    for (int i = 0; i < newThumbnails.length; i++) {
      state.thumbnails[from + i] = newThumbnails[i];
    }
    state.parseImageHrefsState = LoadingState.idle;
    for (int i = 0; i < newThumbnails.length; i++) {
      update(['$onlineImageId::${index + i}']);
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
        onRetry: (e) => Log.error('parse gallery image failed, index: ${index.toString()}', (e as DioError).message),
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

  void toggleAutoMode() {
    if (state.autoMode) {
      closeAutoMode();
    } else {
      enterAutoMode();
    }
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

  void handleSlide(double value) {
    state.readPageInfo.currentIndex = (value - 1).toInt();
    update([sliderId, pageNoId]);
  }

  void handleSlideEnd(double value) {
    jump2PageIndex((value - 1).toInt());
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
    update([sliderId, pageNoId, thumbnailsId]);
  }

  void callbackAfterSwitchLayout() {
    closeAutoMode();
  }
}
