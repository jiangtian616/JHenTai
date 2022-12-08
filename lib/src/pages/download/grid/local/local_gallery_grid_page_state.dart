import 'package:get/get.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../base/grid_base_page_state.dart';

class LocalGalleryGridPageState extends GridBasePageState with Scroll2TopStateMixin {
  @override
  List<String> get allRootGroups => Get.find<LocalGalleryService>().rootDirectories;

  @override
  List<LocalGallery> galleryObjectsWithGroup(String groupName) {
    return Get.find<LocalGalleryService>().path2GalleryDir[groupName] ?? [];
  }
}
