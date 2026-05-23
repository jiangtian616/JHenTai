import 'package:jhentai/src/database/database.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../service/gallery_download_service.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../../mixin/gallery/gallery_download_page_state_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';

class GalleryCategoryGridDownloadPageState
    with
        Scroll2TopStateMixin,
        MultiSelectDownloadPageStateMixin,
        GalleryDownloadPageStateMixin,
        GridBasePageState {
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

  @override
  List<String> get allRootGroups => filteredAuthorGroups;

  @override
  List<GalleryDownloadedData> galleryObjectsWithGroup(String groupName) =>
      galleryDownloadService.gallerysWithAuthor(groupName);
}
