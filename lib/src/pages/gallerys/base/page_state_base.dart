import 'package:flutter/cupertino.dart';

import '../../../model/gallery.dart';
import '../../../widget/loading_state_indicator.dart';

class StateBase {
  List<Gallery> gallerys = List.empty(growable: true);

  int pageCount = -1;
  int? prevPageIndexToLoad;
  int? nextPageIndexToLoad = 0;

  LoadingState refreshState = LoadingState.idle;
  LoadingState loadingState = LoadingState.idle;

  Key galleryCollectionKey = UniqueKey();

  ScrollController scrollController = ScrollController();
}
