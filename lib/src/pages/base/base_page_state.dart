import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/model/search_config.dart';

import '../../model/gallery.dart';
import '../../widget/loading_state_indicator.dart';

class BasePageState {
  List<Gallery> gallerys = List.empty(growable: true);
  SearchConfig searchConfig = SearchConfig();

  int pageCount = -1;
  int? prevPageIndexToLoad;
  int? nextPageIndexToLoad = 0;

  LoadingState refreshState = LoadingState.idle;
  LoadingState loadingState = LoadingState.idle;

  Key galleryCollectionKey = UniqueKey();

  ScrollController scrollController = ScrollController();
  late PageStorageKey pageStorageKey;

  BasePageState() {
    pageStorageKey = PageStorageKey(runtimeType);
  }

  @override
  String toString() {
    return 'BasePageState{gallerys: $gallerys, searchConfig: $searchConfig, pageCount: $pageCount, prevPageIndexToLoad: $prevPageIndexToLoad, nextPageIndexToLoad: $nextPageIndexToLoad, refreshState: $refreshState, loadingState: $loadingState, galleryCollectionKey: $galleryCollectionKey, scrollController: $scrollController, pageStorageKey: $pageStorageKey}';
  }
}
