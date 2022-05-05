import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:retry/retry.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../model/gallery_image.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import 'read_page_state.dart';

const String itemId = 'itemId';
const String parseImageHrefsStateId = 'parseImageHrefsStateId';
const String parseImageUrlStateId = 'parseImageUrlStateId';
const String currentTimeId = 'currentTimeId';
const String batteryId = 'batteryId';
const String pageNoId = 'pageNoId';

class ReadPageLogic extends GetxController {
  final ReadPageState state = ReadPageState();
  final GalleryDownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();

  late Worker readDirectionListener;
  late Timer refreshCurrentTimeAndBatteryLevelTimer;

  @override
  void onInit() {
    /// record reading progress
    state.itemPositionsListener.itemPositions.addListener(() {
      recordReadProgress(getCurrentVisibleItems().first.index);
    });

    /// when direction changes, keep read position
    readDirectionListener = ever(ReadSetting.readDirection, (value) {
      state.initialIndex = state.readIndexRecord;
      state.pageController = PageController(initialPage: state.readIndexRecord);
    });

    refreshCurrentTimeAndBatteryLevelTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => update([currentTimeId, batteryId]),
    );

    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();

    storageService.write('readIndexRecord::${state.gid}', state.readIndexRecord);
    restoreSystemBar();
    readDirectionListener.dispose();

    /// update read progress in detail page
    DetailsPageLogic.current?.update([bodyId]);

    refreshCurrentTimeAndBatteryLevelTimer.cancel();
  }

  void beginToParseImageHref(int index) {
    if (state.parseImageHrefsState == LoadingState.loading) {
      return;
    }

    state.parseImageHrefsState = LoadingState.loading;
    SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
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
          galleryUrl: state.galleryUrl,
          thumbnailsPageNo: index ~/ SiteSetting.thumbnailsCountPerPage.value,
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
      update(['$itemId::${index + i}']);
    }
  }

  void beginToParseImageUrl(int index, bool reParse) {
    if (state.parseImageUrlStates[index] == LoadingState.loading) {
      return;
    }
    state.parseImageUrlStates[index] = LoadingState.loading;
    SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
      _parseImageUrl(index, reParse);
    });
  }

  Future<void> _parseImageUrl(int index, bool reParse) async {
    Log.verbose('begin to parse image url of $index', false);
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
    update(['$itemId::$index']);
  }

  /// to prev image or screen
  void toPrev() {
    if (ReadSetting.readDirection.value != ReadDirection.top2bottom) {
      return _toPrevImage();
    }

    switch (ReadSetting.turnPageMode.value) {
      case TurnPageMode.image:
        return _toPrevImage();
      case TurnPageMode.screen:
        return _toPrevScreen();
      case TurnPageMode.adaptive:
        List<ItemPosition> positions = getCurrentVisibleItems();
        if (positions.length > 1) {
          return _toPrevImage();
        }
        return _toPrevScreen();
    }
  }

  /// to next image or screen
  void toNext() {
    if (ReadSetting.readDirection.value != ReadDirection.top2bottom) {
      return _toNextImage();
    }

    switch (ReadSetting.turnPageMode.value) {
      case TurnPageMode.image:
        return _toNextImage();
      case TurnPageMode.screen:
        return _toNextScreen();
      case TurnPageMode.adaptive:
        List<ItemPosition> positions = getCurrentVisibleItems();
        if (positions.length > 1) {
          return _toNextImage();
        }
        return _toNextScreen();
    }
  }

  void _toPrevImage() {
    int targetIndex;

    /// ListView
    if (ReadSetting.readDirection.value == ReadDirection.top2bottom) {
      ItemPosition firstPosition = getCurrentVisibleItems().first;
      targetIndex = firstPosition.itemLeadingEdge < 0 ? firstPosition.index : firstPosition.index - 1;
      _toPage(max(targetIndex, 0));
    }

    /// PageView
    else {
      targetIndex = (state.pageController!.page! - 1).toInt();
    }

    _toPage(max(targetIndex, 0));
  }

  /// scroll or jump until last image in viewport currently reach top
  void _toNextImage() {
    int targetIndex;

    if (ReadSetting.readDirection.value == ReadDirection.top2bottom) {
      ItemPosition lastPosition = getCurrentVisibleItems().last;
      targetIndex = (lastPosition.itemLeadingEdge > 0 && lastPosition.itemTrailingEdge > 1)
          ? lastPosition.index
          : lastPosition.index + 1;
    } else {
      targetIndex = (state.pageController!.page! + 1).toInt();
    }

    _toPage(min(targetIndex, state.pageCount));
  }

  void _toNextScreen() {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      _jump2NextScreen();
    } else {
      _scroll2NextScreen();
    }
  }

  void _toPrevScreen() {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      _jump2PrevScreen();
    } else {
      _scroll2PrevScreen();
    }
  }

  void _toPage(int pageIndex) {
    if (ReadSetting.enablePageTurnAnime.isFalse) {
      _jump2Page(pageIndex);
    } else {
      _scroll2Page(pageIndex);
    }
  }

  void _scroll2Page(int pageIndex) {
    if (ReadSetting.readDirection.value == ReadDirection.top2bottom) {
      state.itemScrollController.scrollTo(
        index: pageIndex,
        duration: const Duration(milliseconds: 200),
      );
    } else if (state.pageController?.hasClients ?? false) {
      state.pageController?.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
      );
    }
    update(['menu']);
  }

  void _jump2Page(int pageIndex) {
    if (ReadSetting.readDirection.value == ReadDirection.top2bottom) {
      state.itemScrollController.jumpTo(index: pageIndex);
      update(['menu']);
    } else {
      state.pageController?.jumpToPage(pageIndex);
      update(['menu']);
    }
  }

  void _scroll2NextScreen() {
    state.itemScrollController.scrollOffset(
      offset: _getVisibleHeight(),
      duration: const Duration(milliseconds: 200),
    );
  }

  void _jump2NextScreen() {
    state.itemScrollController.scrollOffset(
      offset: _getVisibleHeight(),
      duration: const Duration(milliseconds: 1),
    );
  }

  void _scroll2PrevScreen() {
    state.itemScrollController.scrollOffset(
      offset: -_getVisibleHeight(),
      duration: const Duration(milliseconds: 200),
    );
  }

  void _jump2PrevScreen() {
    state.itemScrollController.scrollOffset(
      offset: -_getVisibleHeight(),
      duration: const Duration(milliseconds: 1),
    );
  }

  void toggleMenu() {
    state.isMenuOpen = !state.isMenuOpen;
    update(['menu']);
  }

  void onScaleEnd(BuildContext context, ScaleEndDetails details, PhotoViewControllerValue controllerValue) {
    if (controllerValue.scale! < 1) {
      state.photoViewScaleStateController.reset();
    }
  }

  void handleSlide(double value) {
    state.readIndexRecord = (value - 1).toInt();
    update(['menu', pageNoId]);
  }

  void handleSlideEnd(double value) {
    _jump2Page((value - 1).toInt());
  }

  void recordReadProgress(int index) {
    state.readIndexRecord = index;
    update(['menu', pageNoId]);
  }

  void hideSystemBarIfNeeded(bool hide) {
    if (hide) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void restoreSystemBar() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  List<ItemPosition> getCurrentVisibleItems() {
    return _filterAndSortItems(state.itemPositionsListener.itemPositions.value);
  }

  /// for some reason like slow loading of some image, [ItemPositions] may be not in index order, and even some of
  /// them are not in viewport
  List<ItemPosition> _filterAndSortItems(Iterable<ItemPosition> positions) {
    positions = positions.where((item) => !(item.itemTrailingEdge < 0 || item.itemLeadingEdge > 1)).toList();
    (positions as List<ItemPosition>).sort((a, b) => a.index - b.index);
    return positions;
  }

  double _getVisibleHeight() {
    return screenHeight -
        Get.mediaQuery.padding.bottom -
        (ReadSetting.enableImmersiveMode.isTrue ? 0 : Get.mediaQuery.padding.top);
  }
}
