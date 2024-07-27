import 'dart:async';

import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';

import '../../../../database/database.dart';
import '../../../../widget/grouped_list.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';

class GalleryListDownloadPageState with Scroll2TopStateMixin, GalleryDownloadPageStateMixin, MultiSelectDownloadPageStateMixin {
  Set<String> displayGroups = {};
  Completer<void> displayGroupsCompleter = Completer<void>();
  
  final GroupedListController<String, GalleryDownloadedData> groupedListController = GroupedListController<String, GalleryDownloadedData>();
}
