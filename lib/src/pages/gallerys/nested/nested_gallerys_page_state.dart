import 'package:flutter/material.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../model/gallery.dart';

class NestedGallerysPageState {
  late List<String> tabBarNames;
  late List<Key> tabBarViewKeys;

  late List<List<Gallery>> gallerys;

  late List<int> pageCount;
  late List<int?> prevPageIndexToLoad;
  late List<int?> nextPageIndexToLoad;

  late List<Key> galleryCollectionKeys;

  late List<LoadingState> refreshState;
  late List<LoadingState> loadingState;

  NestedGallerysPageState() {
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
