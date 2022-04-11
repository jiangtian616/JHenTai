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
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:retry/retry.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../database/database.dart';
import '../../model/gallery_image.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/eh_spider_parser.dart';
import 'read_page_state.dart';

class ReadPageLogic extends GetxController {
  final ReadPageState state = ReadPageState();
  final DownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();

  ReadPageLogic() {
    state.type = Get.parameters['type']!;
    state.initialIndex = int.parse(Get.parameters['initialIndex']!);
    state.pageCount = int.parse(Get.parameters['pageCount']!);
    state.gid = int.parse(Get.parameters['gid']!);
    state.galleryUrl = Get.parameters['galleryUrl']!;
    state.readIndexRecord = storageService.read('readIndexRecord::${state.gid}') ?? 0;
    state.pageController = PageController(initialPage: state.initialIndex);
    state.errorMsg = List.generate(state.pageCount, (index) => RxnString(null));

    if (state.type == 'local') {
      GalleryDownloadedData gallery = Get.arguments as GalleryDownloadedData;
      state.thumbnails = downloadService.gid2ImageHrefs[gallery.gid]!;
      state.images = downloadService.gid2Images[gallery.gid]!;
    } else if (state.type == 'online') {
      if (Get.arguments == null) {
        state.thumbnails = List.generate(state.pageCount, (index) => Rxn(null), growable: true);
      } else {
        /// has load some thumbnails at detail page
        List<GalleryThumbnail> parsedThumbnails = Get.arguments as List<GalleryThumbnail>;
        state.thumbnails = List.generate(
          state.pageCount,
          (index) => index < parsedThumbnails.length ? Rxn(parsedThumbnails[index]) : Rxn(null),
          growable: true,
        );
      }
      state.images = List.generate(state.pageCount, (index) => Rxn(null));
      state.imageUrlParsingStates = List.generate(state.pageCount, (index) => LoadingState.idle.obs);
    }

    /// record reading progress
    state.itemPositionsListener.itemPositions.addListener(() {
      recordReadProgress(getCurrentVisibleItems().first.index);
    });

    /// when direction changes, keep read position
    ever(ReadSetting.readDirection, (value) {
      state.initialIndex = state.readIndexRecord;
      state.pageController = PageController(initialPage: state.readIndexRecord);
    });
  }

  @override
  void onClose() {
    storageService.write('readIndexRecord::${state.gid}', state.readIndexRecord);

    /// update read progress in detail page
    DetailsPageLogic.current?.update([bodyId]);
    restoreSystemBar();
    super.onClose();
  }

  Future<void> beginParsingImageHref(int index) async {
    if (state.imageHrefParsingState.value == LoadingState.loading) {
      return;
    }
    Log.info('begin to load Thumbnails from $index', false);

    state.imageHrefParsingState.value = LoadingState.loading;

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
      );
    } on DioError catch (e) {
      Log.error('get thumbnails error!', e.message);
      state.imageHrefParsingState.value = LoadingState.error;
      if (e.error is EHException) {
        state.errorMsg[index].value = e.error.msg;
        return;
      }
      await beginParsingImageHref(index);
      return;
    }

    int from = index ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
    for (int i = 0; i < newThumbnails.length; i++) {
      state.thumbnails[from + i].value = newThumbnails[i];
    }
    state.imageHrefParsingState.value = LoadingState.success;
    return;
  }

  Future<void> beginParsingImageUrl(int index) async {
    if (state.imageUrlParsingStates![index].value == LoadingState.loading) {
      return;
    }

    state.imageUrlParsingStates![index].value = LoadingState.loading;

    GalleryImage image;
    try {
      image = await retry(
        () => EHRequest.requestImagePage(
          state.thumbnails[index].value!.href,
          parser: EHSpiderParser.imagePage2GalleryImage,
        ),
        maxAttempts: 3,
        retryIf: (e) => e is DioError && e.error is! EHException,
      );
    } on DioError catch (e) {
      Log.error('parse gallery image failed, index: ${index.toString()}', e.message);
      state.imageUrlParsingStates![index].value = LoadingState.error;
      if (e.error is EHException) {
        state.errorMsg[index].value = e.error.msg;
      }
      return;
    }

    state.images[index].value = image;
    state.imageUrlParsingStates![index].value = LoadingState.success;
  }

  /// to prev image or screen
  void toPrev() {
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
    if (state.itemScrollController.isAttached) {
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
      /// [jump] will redraw image and cause a blink, use [scrollTo] instead
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        state.itemScrollController.scrollTo(
          index: pageIndex,
          duration: const Duration(milliseconds: 1),
        );
        update(['menu']);
      });
    } else if (state.pageController?.hasClients ?? false) {
      state.pageController?.jumpToPage(pageIndex);
      update(['menu']);
    }
  }

  void _scroll2NextScreen() {
    ItemPosition lastPosition = getCurrentVisibleItems().last;

    if (lastPosition.itemTrailingEdge == 1) {
      _toNextImage();
    } else {}
  }

  void _jump2NextScreen() {}

  void _scroll2PrevScreen() {}

  void _jump2PrevScreen() {}

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
    update(['menu']);
  }

  void handleSlideEnd(double value) {
    _jump2Page((value - 1).toInt());
  }

  void recordReadProgress(int index) {
    state.readIndexRecord = index;
    update(['menu']);
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
}
