import 'dart:async';

import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';

import '../../../../database/database.dart';
import '../../../../widget/grouped_list.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';

class GalleryListDownloadPageState with Scroll2TopStateMixin, GalleryDownloadPageStateMixin, MultiSelectDownloadPageStateMixin {
  Set<String> displayGroups = {};
  Completer<void> displayGroupsCompleter = Completer<void>();
  String groupFilterKeyword = '';

  List<String> get filteredGroups {
    String keyword = groupFilterKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return galleryDownloadService.allGroups;
    }
    return galleryDownloadService.allGroups.where((group) => group.toLowerCase().contains(keyword)).toList();
  }

  final GroupedListController<String, GalleryDownloadedData> groupedListController = GroupedListController<String, GalleryDownloadedData>();
}
