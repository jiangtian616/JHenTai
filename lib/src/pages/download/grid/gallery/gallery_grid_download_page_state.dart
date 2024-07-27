import 'package:get/get.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../service/gallery_download_service.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../../mixin/gallery/gallery_download_page_state_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';

class GalleryGridDownloadPageState with Scroll2TopStateMixin, MultiSelectDownloadPageStateMixin, GalleryDownloadPageStateMixin, GridBasePageState {
  @override
  List<String> get allRootGroups => galleryDownloadService.allGroups;

  @override
  List<GalleryDownloadedData> galleryObjectsWithGroup(String groupName) =>
      galleryDownloadService.gallerys.where((gallery) => galleryDownloadService.galleryDownloadInfos[gallery.gid]?.group == groupName).toList();
}
