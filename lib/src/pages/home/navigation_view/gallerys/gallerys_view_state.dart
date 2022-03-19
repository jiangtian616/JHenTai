import 'package:jhentai/src/model/tab_bar_config.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/gallery.dart';

class GallerysViewState {
  late List<TabBarConfig> tabBarConfigs;

  late List<LoadingState> loadingState;

  late List<int> nextPageIndexToLoad;

  late List<int> pageCount;

  late List<List<Gallery>> gallerys;

  GallerysViewState() {
    tabBarConfigs = List.generate(9, (index) => TabBarConfig(name: '画廊'));
    loadingState = List.generate(tabBarConfigs.length, (index) => LoadingState.idle);
    nextPageIndexToLoad = List.generate(tabBarConfigs.length, (index) => 0);
    pageCount = List.generate(tabBarConfigs.length, (index) => -1);
    gallerys = List.generate(tabBarConfigs.length, (index) => List.empty(growable: true));
  }

  /// generally, i want to put all method into Logic class, leaving only data int State class, but logic class
  /// has extended [GetxController] so can't extend [LoadingMoreBase] which is needed in [LoadingMoreList] also,
  /// so i choose put method about handling data in State class.
}
