import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../model/gallery.dart';
import '../../routes/routes.dart';
import '../../service/tag_translation_service.dart';
import '../../utils/log.dart';
import '../../utils/route_util.dart';
import '../../utils/snack_util.dart';
import '../../widget/jump_page_dialog.dart';
import '../../widget/loading_state_indicator.dart';
import 'base_page_state.dart';

abstract class BasePageLogic extends GetxController {
  BasePageState get state;

  String get pageId;

  String get appBarId;

  String get bodyId;

  String get refreshStateId;

  String get loadingStateId;

  bool get useSearchConfig => false;

  bool get autoLoadForFirstTime => true;

  int get tabIndex;

  final TagTranslationService tagTranslationService = Get.find();
  final StorageService _storageService = Get.find();

  @override
  void onInit() {
    super.onInit();

    Get.find<DesktopLayoutPageLogic>().state.scrollControllers[tabIndex] = state.scrollController;

    if (useSearchConfig) {
      Map<String, dynamic>? map = _storageService.read('searchConfig: $runtimeType');
      if (map != null) {
        state.searchConfig = SearchConfig.fromJson(map);
      }
    }

    if (autoLoadForFirstTime) {
      loadMore();
    }
  }

  @override
  void onClose() {
    state.scrollController.dispose();
    super.onClose();
  }

  /// pull-down
  Future<void> handlePullDown() async {
    if (state.prevPageIndexToLoad == null) {
      await handleRefresh();
    } else {
      await loadBefore();
    }
  }

  /// pull-down to refresh
  Future<void> handleRefresh() async {
    if (state.refreshState == LoadingState.loading) {
      return;
    }

    state.refreshState = LoadingState.loading;
    update([refreshStateId]);

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await getGallerysAndPageInfoByPage(0);
    } on DioError catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.refreshState = LoadingState.error;
      update([refreshStateId]);
      return;
    }

    state.gallerys = gallerysAndPageInfo[0];
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];
    state.galleryCollectionKey = UniqueKey();

    state.refreshState = LoadingState.idle;
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }
    update([pageId]);
  }

  Future<void> clearAndRefresh() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }
    if (state.loadingState == LoadingState.idle) {
      state.loadingState = LoadingState.loading;
    }

    state.gallerys.clear();
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = 0;
    state.pageCount = -1;

    if (state.scrollController.hasClients) {
      state.scrollController.jumpTo(0);
    }

    update([pageId]);

    loadMore(checkLoadingState: false);
  }

  /// pull-down to load page before(after jumping to a certain page)
  Future<void> loadBefore() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState;
    state.loadingState = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await getGallerysAndPageInfoByPage(state.prevPageIndexToLoad!);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(gallerysAndPageInfo[0] as List<Gallery>, state.gallerys);
    state.gallerys.insertAll(0, gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];

    state.loadingState = LoadingState.idle;
    update([pageId]);
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore({bool checkLoadingState = true}) async {
    if (checkLoadingState && state.loadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState;
    state.loadingState = LoadingState.loading;
    if (prevState == LoadingState.error || prevState == LoadingState.noData) {
      update([loadingStateId]);
    }

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await getGallerysAndPageInfoByPage(state.nextPageIndexToLoad!);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(gallerysAndPageInfo[0] as List<Gallery>, state.gallerys);
    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];

    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }
    update([pageId]);
  }

  Future<void> jumpPage(int pageIndex) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.gallerys.clear();
    state.loadingState = LoadingState.loading;
    update([pageId]);
    state.scrollController.jumpTo(0);

    pageIndex = max(pageIndex, 0);
    pageIndex = min(pageIndex, state.pageCount - 1);
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = null;

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await getGallerysAndPageInfoByPage(pageIndex);
    } on DioError catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];

    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }
    update([pageId]);
  }

  Future<void> handleTapJumpButton() async {
    int? pageIndex = await Get.dialog(
      JumpPageDialog(
        totalPageNo: state.pageCount,
        currentNo: state.nextPageIndexToLoad ?? state.pageCount,
      ),
    );

    if (pageIndex != null) {
      jumpPage(pageIndex);
    }
  }

  Future<void> handleTapFilterButton([EHSearchConfigDialogType searchConfigDialogType = EHSearchConfigDialogType.filter]) async {
    Map<String, dynamic>? result = await Get.dialog(
      EHSearchConfigDialog(searchConfig: state.searchConfig, type: searchConfigDialogType),
    );

    if (result == null) {
      return;
    }

    SearchConfig searchConfig = result['searchConfig'];
    state.searchConfig = searchConfig;

    /// No need to save at search page
    if (useSearchConfig) {
      _storageService.write('searchConfig: $runtimeType', searchConfig.toJson());
    }

    clearAndRefresh();
  }

  /// click the card and enter details page
  void handleTapCard(Gallery gallery) async {
    toNamed(Routes.details, arguments: gallery);
  }

  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex);

  Future<void> translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    await tagTranslationService.translateGalleryTagsIfNeeded(gallerys);
  }

  /// in case that new gallery is uploaded.
  void cleanDuplicateGallery(List<Gallery> newGallerys, List<Gallery> gallerys) {
    newGallerys.removeWhere((newGallery) => gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }
}
