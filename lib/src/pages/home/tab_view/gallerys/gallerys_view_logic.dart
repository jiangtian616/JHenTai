import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/gallery_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/tab_bar_config.dart';
import '../../../../setting/tab_bar_setting.dart';
import '../../../../utils/eh_spider_parser.dart';
import 'gallerys_view_state.dart';
import '../../../../model/gallery.dart';

class GallerysViewLogic extends GetxController with GetTickerProviderStateMixin {
  final GallerysViewState state = GallerysViewState();
  final TagTranslationService tagTranslationService = Get.find();
  final StorageService storageService = Get.find();
  late TabController tabController = TabController(length: TabBarSetting.configs.length, vsync: this);

  @override
  void onInit() {
    /// listen to TabBarSetting
    ever(TabBarSetting.configs, (List<TabBarConfig> newConfigs) {
      /// add a tab at last
      if (TabBarSetting.configs.length > state.gallerys.length) {
        Log.info('find add a tab', false);
        state.tabBarNames.add(newConfigs.last.name);
        state.gallerys.add(List.empty(growable: true));
        state.loadingState.add(LoadingState.idle);
        state.pageCount.add(-1);
        state.nextPageNoToLoad.add(0);

        /// to change the length of a existing TabController, replace it by a new one.
        TabController oldController = tabController;
        tabController = TabController(length: TabBarSetting.configs.length, vsync: this);
        tabController.index = oldController.index;
        oldController.dispose();
      }

      /// remove a tab
      else if (TabBarSetting.configs.length < state.gallerys.length) {
        Log.info('find remove a tab', false);
        int removedIndex = state.tabBarNames.indexWhere(
            (name) => TabBarSetting.configs.firstWhereOrNull((newConfig) => name == newConfig.name) == null);

        state.gallerys.removeAt(removedIndex);
        state.loadingState.removeAt(removedIndex);
        state.pageCount.removeAt(removedIndex);
        state.nextPageNoToLoad.removeAt(removedIndex);

        /// to change the length of a existing TabController, replace it by a new one.
        TabController oldController = tabController;
        tabController = TabController(length: TabBarSetting.configs.length, vsync: this);
        tabController.index = max(oldController.index - 1, 0);
        oldController.dispose();
      }

      /// update a tab(reorder or update config)
      else {
        Log.info('find update a tab', false);
      }
      update();
    });
    super.onInit();
  }

  /// pull-down refresh
  Future<void> handleRefresh(int tabIndex) async {
    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    List<Gallery> newGallerys;
    int pageCount;
    state.loadingState[tabIndex] = LoadingState.loading;
    update();

    try {
      List<dynamic> gallerysAndPageCount = await _getGallerysByPage(tabIndex, 0);
      newGallerys = gallerysAndPageCount[0];
      pageCount = gallerysAndPageCount[1];
    } on DioError catch (e) {
      Log.error('refresh gallery failed', e.message);
      Get.snackbar('refresh gallery failed', e.message, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update();
      return;
    }

    state.nextPageNoToLoad[tabIndex] = 1;
    state.gallerys[tabIndex].clear();
    state.gallerys[tabIndex] = newGallerys;
    state.pageCount[tabIndex] = pageCount;
    if (state.pageCount[tabIndex] == 0) {
      state.loadingState[tabIndex] = LoadingState.noData;
    } else if (state.pageCount[tabIndex] == state.nextPageNoToLoad[tabIndex]) {
      state.loadingState[tabIndex] = LoadingState.noMore;
    } else {
      state.loadingState[tabIndex] = LoadingState.idle;
    }
    update();
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> handleLoadMore(int tabIndex) async {
    if (state.loadingState[tabIndex] == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState[tabIndex];
    state.loadingState[tabIndex] = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update();
    }

    try {
      List<dynamic> gallerysAndPageCount = await _getGallerysByPage(tabIndex, state.nextPageNoToLoad[tabIndex]);
      state.gallerys[tabIndex].addAll(gallerysAndPageCount[0]);
      state.pageCount[tabIndex] = gallerysAndPageCount[1];
    } on DioError catch (e) {
      Log.error('get gallerys failed', e.message);
      Get.snackbar('getGallerysFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.loadingState[tabIndex] = LoadingState.error;
      update();
      return;
    }

    state.nextPageNoToLoad[tabIndex]++;
    if (state.pageCount[tabIndex] == 0) {
      state.loadingState[tabIndex] = LoadingState.noData;
    } else if (state.pageCount[tabIndex] == state.nextPageNoToLoad[tabIndex]) {
      state.loadingState[tabIndex] = LoadingState.noMore;
    } else {
      state.loadingState[tabIndex] = LoadingState.idle;
    }

    update();
  }

  /// add customized tab
  void handleAddTab(String name, SearchConfig config) {
    TabBarSetting.addTab(name, config);
    state.gallerys.add(List.empty(growable: true));
    state.loadingState.add(LoadingState.idle);
    state.pageCount.add(-1);
    state.nextPageNoToLoad.add(0);

    /// to change the length of a existing TabController, replace it by a new one.
    TabController oldController = tabController;
    tabController = TabController(length: TabBarSetting.configs.length, vsync: this);
    tabController.index = oldController.index;

    update();
    oldController.dispose();
  }

  /// click the card and enter details page
  void handleTapCard(Gallery gallery) async {
    Get.toNamed(Routes.details, arguments: gallery);
  }

  Future<List<dynamic>> _getGallerysByPage(int tabIndex, int pageNo) async {
    Log.info('get Tab $tabIndex gallery data, pageNo:$pageNo', false);

    List<dynamic> gallerysAndPageCount = await () async {
      if (TabBarSetting.configs[tabIndex].searchConfig.searchType == SearchType.history) {
        List<String>? galleryUrls = storageService.read<List>('history')?.map((e) => e as String).toList();
        if (galleryUrls == null) {
          return [<Gallery>[], 0];
        }
        List<Gallery> gallerys = await Future.wait(galleryUrls.map((url) => EHRequest.getGalleryByUrl(url)).toList());
        return [gallerys, 1];
      }
      return await EHRequest.getGallerysListAndPageCountByPageNo(
          pageNo, TabBarSetting.configs[tabIndex].searchConfig, EHSpiderParser.parseGalleryList);
    }();

    await tagTranslationService.translateGalleryTagsIfNeeded(gallerysAndPageCount[0]);

    return gallerysAndPageCount;
  }
}
