import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../model/gallery.dart';
import '../../widget/loading_state_indicator.dart';

class OldBasePageState extends BasePageState {
  int pageCount = -1;
  int? prevPageIndexToLoad;
  int? nextPageIndexToLoad = 0;
}
