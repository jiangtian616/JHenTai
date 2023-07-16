import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';

import '../../exception/eh_exception.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
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
  BasePageState get state;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

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
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true);
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    } on EHException catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true);
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    }

    handleGalleryByLocalTags(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys = galleryPage.gallerys;
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;
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
    state.seek = DateTime.now();
    state.totalCount = null;
    state.favoriteSortOrder = null;

    jump2Top();

    updateSafely();

    loadMore(checkLoadingState: false);
  }

  /// pull-down to load page before(after jumping to a certain page), after load, we must restore [state.downloadState]
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
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    } on EHException catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(galleryPage.gallerys);

    handleGalleryByLocalTags(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys.insertAll(0, galleryPage.gallerys);
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;

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
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHException catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    cleanDuplicateGallery(galleryPage.gallerys);

    handleGalleryByLocalTags(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys.addAll(galleryPage.gallerys);
    state.totalCount = galleryPage.totalCount;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }

  Future<void> jumpPage(DateTime dateTime) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    Log.info('Jump page to $dateTime');

    state.gallerys.clear();
    state.loadingState = LoadingState.loading;
    updateSafely();

    state.scrollController.jumpTo(0);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(nextGid: state.nextGid, prevGid: state.prevGid, seek: dateTime);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHException catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    handleGalleryByLocalTags(galleryPage.gallerys);

    await translateGalleryTagsIfNeeded(galleryPage.gallerys);

    state.gallerys = galleryPage.gallerys;
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;
    state.galleryCollectionKey = UniqueKey();

    state.seek = dateTime;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }

  Future<void> handleTapJumpButton() async {
    DateTime? dateTime = await showDatePicker(
      context: Get.context!,
      initialDate: state.seek,
      currentDate: DateTime.now(),
      firstDate: DateTime(2007),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (dateTime != null) {
      jumpPage(dateTime);
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
      saveSearchConfig(searchConfig);
    }

    handleClearAndRefresh();
  }

  void handleTapGalleryCard(Gallery gallery) async {
    toRoute(
      Routes.details,
      arguments: {
        'gid': gallery.gid,
        'galleryUrl': gallery.galleryUrl,
        'gallery': gallery,
      },
    );
  }

  void handleLongPressCard(BuildContext context, Gallery gallery) async {}

  void handleSecondaryTapCard(BuildContext context, Gallery gallery) async {}

  Future<GalleryPageInfo> getGalleryPage({String? prevGid, String? nextGid, DateTime? seek}) {
    Log.info('$runtimeType get data, prevGid:$prevGid, nextGid:$nextGid');

    return EHRequest.requestGalleryPage(
      prevGid: prevGid,
      nextGid: nextGid,
      seek: seek,
      searchConfig: state.searchConfig,
      parser: EHSpiderParser.galleryPage2GalleryPageInfo,
    );
  }

  void saveSearchConfig(SearchConfig searchConfig) {
    storageService.write('searchConfig: $runtimeType', searchConfig.toJson());
  }

  Future<void> translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    await tagTranslationService.translateGalleryTagsIfNeeded(gallerys);
  }

  /// deal with the first and last page
  void cleanDuplicateGallery(List<Gallery> newGallerys) {
    newGallerys.removeWhere((newGallery) => state.gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }

  void handleGalleryByLocalTags(List<Gallery> newGallerys) {
    if (newGallerys.isEmpty) {
      return;
    }
    if (MyTagsSetting.localTagSets.isEmpty) {
      return;
    }
    newGallerys.where((newGallery) => newGallery.tags.values.flattened.any((tag) => MyTagsSetting.containLocalTag(tag.tagData))).forEach((gallery) {
      gallery.hasLocalFilteredTag = true;
    });

    // if all gallerys are filtered, we keep the first one to indicate
    if (newGallerys.every((gallery) => gallery.hasLocalFilteredTag)) {
      newGallerys.removeRange(1, newGallerys.length);
    } else {
      newGallerys.removeWhere((gallery) => gallery.hasLocalFilteredTag);
    }
  }
}
