import 'dart:ui';

import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/base/page_state_base.dart';

import '../../../consts/eh_consts.dart';
import '../../../model/gallery.dart';
import '../../../model/search_config.dart';
import '../../../network/eh_request.dart';
import '../../../routes/routes.dart';
import '../../../service/history_service.dart';
import '../../../service/storage_service.dart';
import '../../../service/tag_translation_service.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/app_state_listener.dart';
import '../../../widget/loading_state_indicator.dart';
import '../simple/gallerys_page_state.dart';

abstract class LogicBase extends GetxController {
  StateBase get state;

  String get appBarId;
  String get bodyId;
  String get refreshStateId;
  String get loadingStateId;

  final TagTranslationService _tagTranslationService = Get.find();

  @override
  void onInit() {
    super.onInit();
    loadMore();
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
    update([bodyId]);
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

    _cleanDuplicateGallery(gallerysAndPageInfo[0] as List<Gallery>, state.gallerys);
    state.gallerys.insertAll(0, gallerysAndPageInfo[0]);
    state.pageCount = gallerysAndPageInfo[1];
    state.prevPageIndexToLoad = gallerysAndPageInfo[2];
    state.nextPageIndexToLoad = gallerysAndPageInfo[3];

    state.loadingState = LoadingState.idle;
    update([bodyId]);
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore() async {
    if (state.loadingState == LoadingState.loading) {
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

    _cleanDuplicateGallery(gallerysAndPageInfo[0] as List<Gallery>, state.gallerys);
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
    update([appBarId, bodyId, loadingStateId]);
  }

  /// click the card and enter details page
  void handleTapCard(Gallery gallery) async {
    toNamed(Routes.details, arguments: gallery);
  }

  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageNo);

  Future<void> translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    await _tagTranslationService.translateGalleryTagsIfNeeded(gallerys);
  }

  /// in case that new gallery is uploaded.
  void _cleanDuplicateGallery(List<Gallery> newGallerys, List<Gallery> gallerys) {
    newGallerys.removeWhere((newGallery) => gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }
}
