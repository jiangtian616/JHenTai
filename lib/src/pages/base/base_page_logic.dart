import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../model/gallery.dart';
import '../../network/eh_request.dart';
import '../../routes/routes.dart';
import '../../service/tag_translation_service.dart';
import '../../setting/user_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../../utils/route_util.dart';
import '../../utils/snack_util.dart';
import '../../utils/toast_util.dart';
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

  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();

  @override
  void onInit() {
    super.onInit();

    if (useSearchConfig) {
      Map<String, dynamic>? map = storageService.read('searchConfig: $runtimeType');
      if (map != null) {
        state.searchConfig = SearchConfig.fromJson(map);
      }
    }

    if (autoLoadForFirstTime) {
      if (autoLoadNeedLogin && !UserSetting.hasLoggedIn()) {
        state.loadingState = LoadingState.noData;
        updateSafely([bodyId]);
        Get.engine.addPostFrameCallback((_) => toast('needLoginToOperate'.tr));
        return;
      }

      loadMore();
    }
  }

  /// pull-down
  Future<void> handlePullDown() async {
    if (state.prevGid == null) {
      return handleRefresh();
    }

    return loadBefore();
  }

  /// not clear current data before refresh
  /// [updateId] is for subclass to override
  Future<void> handleRefresh({String? updateId}) async {
    if (state.refreshState == LoadingState.loading) {
      return;
    }

    state.refreshState = LoadingState.loading;
    updateSafely([refreshStateId]);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage();
    } on DioError catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    }

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys = galleryPage.gallerys;
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.nextGid = galleryPage.nextGid;
    state.galleryCollectionKey = UniqueKey();

    state.refreshState = LoadingState.idle;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    if (updateId != null) {
      updateSafely([updateId]);
    } else {
      updateSafely();
    }
  }

  /// clear current data first, then refresh
  Future<void> handleClearAndRefresh() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;

    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.totalCount = null;

    jump2Top();

    updateSafely();

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

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(prevGid: state.prevGid);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys.insertAll(0, galleryPage.gallerys);
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;

    state.loadingState = prevState;

    updateSafely();
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore({bool checkLoadingState = true}) async {
    if (checkLoadingState && state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely([loadingStateId]);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(nextGid: state.nextGid);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys.addAll(galleryPage.gallerys);
    state.totalCount = galleryPage.totalCount;
    state.nextGid = galleryPage.nextGid;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }

  Future<void> jumpPage(int pageIndex) async {}

  Future<void> handleTapJumpButton() async {}

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

    handleClearAndRefresh();
  }

  void handleTapGalleryCard(Gallery gallery) async {
    toRoute(
      Routes.details,
      arguments: {
        'galleryUrl': gallery.galleryUrl,
        'gallery': gallery,
      },
    );
  }

  void handleLongPressCard(Gallery gallery) async {}

  void handleSecondaryTapCard(Gallery gallery) async {}

  Future<GalleryPageInfo> getGalleryPage({int? prevGid, int? nextGid}) {
    Log.info('$runtimeType get data, prevGid:$prevGid, nextGid:$nextGid');

    return EHRequest.requestGalleryPage(
      prevGid: prevGid,
      nextGid: nextGid,
      searchConfig: state.searchConfig,
      parser: EHSpiderParser.galleryPage2GalleryPageInfo,
    );
  }

  Future<void> translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    await tagTranslationService.translateGalleryTagsIfNeeded(gallerys);
  }

  /// deal with the first and last page
  void cleanDuplicateGallery(List<Gallery> newGallerys) {
    newGallerys.removeWhere((newGallery) => state.gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }
}
