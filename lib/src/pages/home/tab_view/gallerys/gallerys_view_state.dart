import 'package:flutter/material.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/gallery.dart';

class GallerysViewState {
  late List<String> tabBarNames;

  late List<LoadingState> refreshState;

  late List<LoadingState> loadingState;

  late List<int?> prevPageIndexToLoad;

  late List<int?> nextPageIndexToLoad;

  late List<int> pageCount;

  late List<List<Gallery>> gallerys;

  late List<Key> tabBarViewKeys;

  late List<Key> galleryCollectionKeys;

  GallerysViewState() {
    tabBarNames = TabBarSetting.configs.map((config) => config.name).toList();

    refreshState = List.generate(tabBarNames.length, (index) => LoadingState.idle);
    loadingState = List.generate(tabBarNames.length, (index) => LoadingState.idle);
    prevPageIndexToLoad = List.generate(tabBarNames.length, (index) => null);
    nextPageIndexToLoad = List.generate(tabBarNames.length, (index) => 0);
    pageCount = List.generate(tabBarNames.length, (index) => -1);
    gallerys = List.generate(tabBarNames.length, (index) => List.empty(growable: true));
    tabBarViewKeys = List.generate(tabBarNames.length, (index) => UniqueKey());
    galleryCollectionKeys = List.generate(tabBarNames.length, (index) => UniqueKey());
  }
}
