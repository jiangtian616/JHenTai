import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/gallery.dart';

class GallerysViewState {
  late List<String> tabBarNames;

  late List<LoadingState> loadingState;

  late List<int> nextPageNoToLoad;

  late List<int> pageCount;

  late List<List<Gallery>> gallerys;

  GallerysViewState() {
    tabBarNames = TabBarSetting.configs.map((config) => config.name).toList();

    loadingState = List.generate(tabBarNames.length, (index) => LoadingState.idle);
    nextPageNoToLoad = List.generate(tabBarNames.length, (index) => 0);
    pageCount = List.generate(tabBarNames.length, (index) => -1);
    gallerys = List.generate(tabBarNames.length, (index) => List.empty(growable: true));
  }
}
