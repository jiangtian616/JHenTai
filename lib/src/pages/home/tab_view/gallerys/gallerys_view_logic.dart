import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/main.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/home/tab_view/gallerys/widget/jump_page_dialog.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/tab_bar_config.dart';
import '../../../../setting/tab_bar_setting.dart';
import '../../../../utils/eh_spider_parser.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
import 'gallerys_view_state.dart';
import '../../../../model/gallery.dart';

String appBarId = 'appBarId';
String tabBarId = 'tabBarId';
String bodyId = 'bodyId';
String loadingStateId = 'loadingStateId';

class GallerysViewLogic extends GetxController with GetTickerProviderStateMixin {
  final GallerysViewState state = GallerysViewState();
  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();
  late TabController tabController = TabController(length: TabBarSetting.configs.length, vsync: this);

  void onInit() {
    tabController.addListener(() {
      update([appBarId]);
    });
    super.onInit();
  }

  @override
  void onReady() {
    handleUrlInClipBoard();
    AppListener.registerDidChangeAppLifecycleStateCallback(resumeAndHandleUrlInClipBoard);
    super.onReady();
  }

  /// pull-down
  Future<void> handlePullDown(int tabIndex) async {
    if (state.prevPageIndexToLoad[tabIndex] == -1) {
      await handleRefresh(tabIndex);
    } else {
      await loadBefore(tabIndex);
    }
  }

  /// pull-down to refresh
  Future<void> handleRefresh(int tabIndex) async {
    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    state.loadingState[tabIndex] = LoadingState.loading;
    update([loadingStateId]);

    List<dynamic> gallerysAndPageCount;
    try {
      gallerysAndPageCount = await _getGallerysByPage(tabIndex, 0);
    } on DioError catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.nextPageIndexToLoad[tabIndex] = 1;
    state.gallerys[tabIndex].clear();
    state.gallerys[tabIndex] = gallerysAndPageCount[0];
    state.pageCount[tabIndex] = gallerysAndPageCount[1];
    if (state.pageCount[tabIndex] == 0) {
      state.loadingState[tabIndex] = LoadingState.noData;
    } else if (state.pageCount[tabIndex] == state.nextPageIndexToLoad[tabIndex]) {
      state.loadingState[tabIndex] = LoadingState.noMore;
    } else {
      state.loadingState[tabIndex] = LoadingState.idle;
    }
    update([bodyId]);
  }

  /// pull-down to load page before(after jumping to a certain page)
  Future<void> loadBefore(int tabIndex) async {
    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState[tabIndex];
    state.loadingState[tabIndex] = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    List<dynamic> gallerysAndPageCount;
    try {
      gallerysAndPageCount = await _getGallerysByPage(tabIndex, state.prevPageIndexToLoad[tabIndex]);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    _cleanDuplicateGallery(gallerysAndPageCount[0] as List<Gallery>, state.gallerys[tabIndex]);
    state.gallerys[tabIndex].insertAll(0, gallerysAndPageCount[0]);
    state.pageCount[tabIndex] = gallerysAndPageCount[1];
    state.prevPageIndexToLoad[tabIndex]--;
    state.loadingState[tabIndex] = LoadingState.idle;

    update([bodyId]);
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore(int tabIndex) async {
    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState[tabIndex];
    state.loadingState[tabIndex] = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    List<dynamic> gallerysAndPageCount;
    try {
      gallerysAndPageCount = await _getGallerysByPage(tabIndex, state.nextPageIndexToLoad[tabIndex]);
    } on DioError catch (e) {
      Log.error('getGallerysFailed'.tr, e.message);
      snack('getGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    _cleanDuplicateGallery(gallerysAndPageCount[0] as List<Gallery>, state.gallerys[tabIndex]);
    state.gallerys[tabIndex].addAll(gallerysAndPageCount[0]);
    state.pageCount[tabIndex] = gallerysAndPageCount[1];
    state.nextPageIndexToLoad[tabIndex]++;
    if (state.pageCount[tabIndex] == 0) {
      state.loadingState[tabIndex] = LoadingState.noData;
      state.nextPageIndexToLoad[tabIndex] = 0;
    } else if (state.pageCount[tabIndex] == state.nextPageIndexToLoad[tabIndex]) {
      state.loadingState[tabIndex] = LoadingState.noMore;
    } else {
      state.loadingState[tabIndex] = LoadingState.idle;
    }

    update([appBarId, bodyId, loadingStateId]);
  }

  Future<void> jumpPage(int pageIndex) async {
    int tabIndex = tabController.index;

    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    state.gallerys[tabIndex].clear();
    state.loadingState[tabIndex] = LoadingState.loading;
    update([bodyId]);


    pageIndex = max(pageIndex, 0);
    pageIndex = min(pageIndex, state.pageCount[tabIndex] - 1);
    state.prevPageIndexToLoad[tabIndex] = pageIndex - 1;
    state.nextPageIndexToLoad[tabIndex] = pageIndex;

    List<dynamic> gallerysAndPageCount;
    try {
      gallerysAndPageCount = await _getGallerysByPage(tabIndex, pageIndex);
    } on DioError catch (e) {
      Log.error('refreshGalleryFailed'.tr, e.message);
      snack('refreshGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update([loadingStateId]);
      return;
    }

    state.gallerys[tabIndex].addAll(gallerysAndPageCount[0]);
    state.pageCount[tabIndex] = gallerysAndPageCount[1];
    state.nextPageIndexToLoad[tabIndex]++;
    if (state.pageCount[tabIndex] == 0) {
      state.loadingState[tabIndex] = LoadingState.noData;
    } else if (state.pageCount[tabIndex] == state.nextPageIndexToLoad[tabIndex]) {
      state.loadingState[tabIndex] = LoadingState.noMore;
    } else {
      state.loadingState[tabIndex] = LoadingState.idle;
    }
    update([bodyId]);
  }

  Future<void> handleOpenJumpDialog() async {
    int? pageIndex = await Get.dialog(
      JumpPageDialog(
        totalPageNo: state.pageCount[tabController.index],
        currentNo: state.nextPageIndexToLoad[tabController.index],
      ),
    );
    if (pageIndex != null) {
      jumpPage(pageIndex);
    }
  }

  /// click the card and enter details page
  void handleTapCard(Gallery gallery) async {
    toNamed(Routes.details, arguments: gallery);
  }

  /// add customized tab
  void handleAddTab(TabBarConfig tabBarConfig) {
    Log.info('add a tab', false);
    TabBarSetting.addTab(tabBarConfig);

    state.tabBarNames.add(tabBarConfig.name);
    state.gallerys.add(List.empty(growable: true));
    state.loadingState.add(LoadingState.idle);
    state.pageCount.add(-1);
    state.nextPageIndexToLoad.add(0);

    /// to change the length of a existing TabController, replace it by a new one.
    TabController oldController = tabController;
    tabController = TabController(length: TabBarSetting.configs.length, vsync: this);
    tabController.index = oldController.index;
    oldController.dispose();
    update([tabBarId, bodyId]);
  }

  /// remove tab
  void handleRemoveTab(int index) {
    Log.info('remove a tab', false);

    TabBarSetting.removeTab(index);
    state.tabBarNames.removeAt(index);
    state.gallerys.removeAt(index);
    state.loadingState.removeAt(index);
    state.pageCount.removeAt(index);
    state.nextPageIndexToLoad.removeAt(index);

    /// to change the length of a existing TabController, replace it by a new one.
    TabController oldController = tabController;
    tabController = TabController(length: TabBarSetting.configs.length, vsync: this);
    tabController.index = max(oldController.index - 1, 0);
    oldController.dispose();
    update([tabBarId, bodyId]);
  }

  /// update tab
  void handleUpdateTab(TabBarConfig tabBarConfig) {
    Log.info('update a tab', false);

    int index = state.tabBarNames.indexWhere((name) => name == tabBarConfig.name);

    TabBarSetting.updateTab(index, tabBarConfig);
    state.tabBarNames[index] = tabBarConfig.name;
    update([tabBarId, bodyId]);
  }

  /// reOrder tab
  void handleReOrderTab(int oldIndex, int newIndex) {
    Log.info('reOrder a tab', false);
    if (oldIndex < newIndex) {
      newIndex--;
    }

    TabBarSetting.reOrderTab(oldIndex, newIndex);

    if (newIndex != state.tabBarNames.length - 1) {
      state.tabBarNames.insert(newIndex, state.tabBarNames.removeAt(oldIndex));
      state.gallerys.insert(newIndex, state.gallerys.removeAt(oldIndex));
      state.loadingState.insert(newIndex, state.loadingState.removeAt(oldIndex));
      state.pageCount.insert(newIndex, state.pageCount.removeAt(oldIndex));
      state.nextPageIndexToLoad.insert(newIndex, state.nextPageIndexToLoad.removeAt(oldIndex));
    } else {
      state.tabBarNames.add(state.tabBarNames.removeAt(oldIndex));
      state.gallerys.add(state.gallerys.removeAt(oldIndex));
      state.loadingState.add(state.loadingState.removeAt(oldIndex));
      state.pageCount.add(state.pageCount.removeAt(oldIndex));
      state.nextPageIndexToLoad.add(state.nextPageIndexToLoad.removeAt(oldIndex));
    }

    if (tabController.index == oldIndex) {
      tabController.index = newIndex;
    } else if (oldIndex < tabController.index && tabController.index <= newIndex) {
      tabController.index = tabController.index - 1;
    } else if (newIndex <= tabController.index && tabController.index < oldIndex) {
      tabController.index = tabController.index + 1;
    }
    update([tabBarId, bodyId]);
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void resumeAndHandleUrlInClipBoard(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      handleUrlInClipBoard();
    }
  }

  /// a gallery url exists in clipboard, show dialog to check whether enter detail page
  void handleUrlInClipBoard() async {
    String text = await FlutterClipboard.paste();
    if (!text.startsWith('${EHConsts.EHIndex}/g') && !text.startsWith('${EHConsts.EXIndex}/g')) {
      return;
    }

    snack(
      'galleryUrlDetected'.tr,
      '${'galleryUrlDetectedHint'.tr}: $text',
      onTap: (snackbar) {
        toNamed(Routes.details, arguments: text);
      },
      longDuration: true,
    );
  }

  /// in case that new gallery is uploaded.
  void _cleanDuplicateGallery(List<Gallery> newGallerys, List<Gallery> gallerys) {
    newGallerys
        .removeWhere((newGallery) => gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }

  Future<List<dynamic>> _getGallerysByPage(int tabIndex, int pageNo) async {
    Log.info('get Tab $tabIndex gallery data, pageNo:$pageNo', false);

    List<dynamic> gallerysAndPageCount;
    switch (TabBarSetting.configs[tabIndex].searchConfig.searchType) {
      case SearchType.history:
        gallerysAndPageCount = await _getHistoryGallerys();
        break;
      case SearchType.favorite:
        if (!UserSetting.hasLoggedIn()) {
          gallerysAndPageCount = [<Gallery>[], 0];
          break;
        }
        continue end;
      case SearchType.watched:
        if (!UserSetting.hasLoggedIn()) {
          gallerysAndPageCount = [<Gallery>[], 0];
          break;
        }
        continue end;
      end:
      case SearchType.popular:
      case SearchType.gallery:
        gallerysAndPageCount = await EHRequest.requestGalleryPage(
          pageNo: pageNo,
          searchConfig: TabBarSetting.configs[tabIndex].searchConfig,
          parser: EHSpiderParser.galleryPage2GalleryList,
        );
    }

    await tagTranslationService.translateGalleryTagsIfNeeded(gallerysAndPageCount[0]);
    return gallerysAndPageCount;
  }

  Future<List<dynamic>> _getHistoryGallerys() async {
    List<String>? galleryUrls = storageService.read<List>('history')?.cast<String>();
    if (galleryUrls == null) {
      return [<Gallery>[], 0];
    }

    List<Gallery?> gallerys = List.generate(galleryUrls.length, (index) => null);
    try {
      await Future.wait(
        galleryUrls
            .mapIndexed(
              (index, url) => EHRequest.requestDetailPage(galleryUrl: url, parser: EHSpiderParser.detailPage2Gallery)
                  .then((value) => gallerys[index] = value)
                  .catchError((error) {
                /// 404 => hide or remove
                if (error.response?.statusCode != 404) {
                  Log.error('${'getSomeOfGallerysFailed'.tr}:$url', error.message);
                } else {
                  Log.info('Gallery 404: $url', false);
                }
                throw error;
              }),
            )
            .toList(),
      );
    } on DioError catch (e) {
      snack('getSomeOfGallerysFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
    }

    gallerys.removeWhere((r) => r == null);

    return [gallerys.cast<Gallery>(), 1];
  }
}
