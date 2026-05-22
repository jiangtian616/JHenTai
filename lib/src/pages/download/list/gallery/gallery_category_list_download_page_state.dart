import 'dart:async';

import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/widget/grouped_list.dart';

import '../../../../database/database.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';

class GalleryCategoryListDownloadPageState
    with
        Scroll2TopStateMixin,
        GalleryDownloadPageStateMixin,
        MultiSelectDownloadPageStateMixin {
  Set<String> displayGroups = {};
  Set<String> knownGroups = {};
  Completer<void> displayGroupsCompleter = Completer<void>();
  String authorFilterKeyword = '';

  List<String> get filteredAuthorGroups {
    String keyword = authorFilterKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return galleryDownloadService.authorGroups;
    }
    return galleryDownloadService.authorGroups
        .where((author) => author.toLowerCase().contains(keyword))
        .toList();
  }

  final GroupedListController<String, GalleryDownloadedData>
      groupedListController =
      GroupedListController<String, GalleryDownloadedData>();
}
