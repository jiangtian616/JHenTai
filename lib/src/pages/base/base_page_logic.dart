import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/service/check_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../model/gallery.dart';
import '../../routes/routes.dart';
import '../../service/tag_translation_service.dart';
import '../../setting/user_setting.dart';
import '../../utils/log.dart';
import '../../utils/route_util.dart';
import '../../utils/snack_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/jump_page_dialog.dart';
import '../../widget/loading_state_indicator.dart';
import 'base_page_state.dart';

abstract class BasePageLogic extends GetxController with Scroll2TopLogicMixin {
  @override
  BasePageState get state;

  final String appBarId = 'appBarId';
  final String bodyId = 'bodyId';
  final String refreshStateId = 'refreshStateId';
  final String loadingStateId = 'loadingStateId';

  bool get useSearchConfig => false;

  bool get autoLoadForFirstTime => true;

  bool get autoLoadNeedLogin => false;

  bool get showScroll2TopButton => true;

  int get tabIndex;

  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();

  @override
  void onReady() {
    super.onReady();

    if (Get.isRegistered<DesktopLayoutPageLogic>() && StyleSetting.actualLayout == LayoutMode.desktop) {
      Get.find<DesktopLayoutPageLogic>().state.scrollControllers[tabIndex] = state.scrollController;
    }

    if (useSearchConfig) {
      Map<String, dynamic>? map = storageService.read('searchConfig: $runtimeType');
      if (map != null) {
        state.searchConfig = SearchConfig.fromJson(map);
      }
    }

    if (autoLoadForFirstTime) {
      if (autoLoadNeedLogin && !UserSetting.hasLoggedIn()) {
        state.loadingState = LoadingState.noData;
        update([bodyId]);
        toast('needLoginToOperate'.tr);
        return;
      }

      loadMore();
    }
  }

  /// pull-down
  Future<void> handlePullDown() async {
    if (state.prevPageIndexToLoad == null) {
      return handleRefresh();
    }

    return loadBefore();
  }

  /// not clear current data before refresh
  Future<void> handleRefresh({String? refreshId}) async {
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

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);

    state.gallerys = gallerysAndPageInfo[0];
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];
    state.galleryCollectionKey = UniqueKey();

    state.refreshState = LoadingState.idle;
    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.nextPageIndexToLoad = 0;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    if (refreshId != null) {
      update([refreshId]);
    } else {
      update();
    }

    CheckService.build(
      () => state.nextPageIndexToLoad != null || state.loadingState == LoadingState.noMore,
      errorMsg: 'handleRefresh state.nextPageIndexToLoad == null!',
    ).check();
  }

  /// clear current data first, then refresh
  Future<void> clearAndRefresh() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;

    state.gallerys.clear();
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = 0;
    state.pageCount = -1;

    jump2Top();

    update();

    loadMore(checkLoadingState: false);
  }

  /// pull-down to load page before(after jumping to a certain page), after load, we must restore [state.loadingState]
  /// to [prevState] in case of [prevState] is [noMore]
  Future<void> loadBefore() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState;
    state.loadingState = LoadingState.loading;

    List<dynamic> gallerysAndPageInfo;
    try {
      gallerysAndPageInfo = await getGallerysAndPageInfoByPage(state.prevPageIndexToLoad!);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = prevState;
      update([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(gallerysAndPageInfo[0] as List<Gallery>, state.gallerys);
    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);

    state.gallerys.insertAll(0, gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];

    state.loadingState = prevState;
    update();
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore({bool checkLoadingState = true}) async {
    if (checkLoadingState && state.loadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState;
    state.loadingState = LoadingState.loading;

    if (state.gallerys.isEmpty) {
      /// for [CenterStatusIndicator]
      update([bodyId]);
    } else if (prevState == LoadingState.error || prevState == LoadingState.noData) {
      /// for [LoadMoreIndicator]
      update([loadingStateId]);
    }

    CheckService.build(
      () => state.nextPageIndexToLoad != null,
      errorMsg: 'state.nextPageIndexToLoad == null!',
    ).onFailed(() {
      Log.error('getGallerysFailed'.tr);
      snack('getGallerysFailed'.tr, 'internalError'.tr, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update([loadingStateId]);
    }).check();

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
    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);

    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];

    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.nextPageIndexToLoad = 0;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    update();

    CheckService.build(
      () => state.nextPageIndexToLoad != null || state.loadingState == LoadingState.noMore,
      errorMsg: 'loadMore state.nextPageIndexToLoad == null!',
    ).withUploadParam({
      'state': state,
      'gallerysAndPageInfo': gallerysAndPageInfo,
    }).check(throwExceptionWhenFailed: false);
  }

  Future<void> jumpPage(int pageIndex) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.gallerys.clear();
    state.loadingState = LoadingState.loading;
    update();
    state.scrollController.jumpTo(0);

    pageIndex = max(pageIndex, 0);
    pageIndex = min(pageIndex, state.pageCount - 1);
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = 0;

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

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);

    state.gallerys.addAll(gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];

    if (state.pageCount == 0) {
      state.loadingState = LoadingState.noData;
      state.nextPageIndexToLoad = 0;
    } else if (state.nextPageIndexToLoad == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    update();

    CheckService.build(
      () => state.nextPageIndexToLoad != null || state.loadingState == LoadingState.noMore,
      errorMsg: 'jumpPage state.nextPageIndexToLoad == null!',
    ).check();
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
      storageService.write('searchConfig: $runtimeType', searchConfig.toJson());
    }

    clearAndRefresh();
  }

  /// click the card and enter details page
  void handleTapCard(Gallery gallery) async {
    toRoute(
      Routes.details,
      arguments: {
        'galleryUrl': gallery.galleryUrl,
        'gallery': gallery,
      },
    );
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
