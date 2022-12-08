import 'package:get/get.dart';

import '../../../../database/database.dart';
import '../../../../service/gallery_download_service.dart';
import '../base/grid_base_page_state.dart';

class GalleryGridDownloadPageState extends GridBasePageState {
  @override
  List<String> get allRootGroups => Get.find<GalleryDownloadService>().allGroups;

  @override
  List<GalleryDownloadedData> galleryObjectsWithGroup(String groupName) => Get.find<GalleryDownloadService>()
      .gallerys
      .where((gallery) => Get.find<GalleryDownloadService>().galleryDownloadInfos[gallery.gid]?.group == groupName)
      .toList();
}
