import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/model/search_config.dart';

import '../../model/gallery.dart';
import '../../widget/loading_state_indicator.dart';

class BasePageState with Scroll2TopStateMixin {
  List<Gallery> gallerys = List.empty(growable: true);

  SearchConfig searchConfig = SearchConfig();

  int pageCount = -1;
  int? prevPageIndexToLoad;
  int? nextPageIndexToLoad = 0;

  LoadingState refreshState = LoadingState.idle;
  LoadingState loadingState = LoadingState.idle;

  /// used for refresh
  Key galleryCollectionKey = UniqueKey();

  late PageStorageKey pageStorageKey;

  BasePageState() {
    pageStorageKey = PageStorageKey(runtimeType);
  }

  @override
  String toString() {
    return 'BasePageState{gallerys: $gallerys, searchConfig: $searchConfig, pageCount: $pageCount, prevPageIndexToLoad: $prevPageIndexToLoad, nextPageIndexToLoad: $nextPageIndexToLoad, refreshState: $refreshState, loadingState: $loadingState, galleryCollectionKey: $galleryCollectionKey, scrollController: $scrollController, pageStorageKey: $pageStorageKey}';
  }
}
