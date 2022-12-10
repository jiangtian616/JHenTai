import 'package:get/get.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../service/local_gallery_service.dart';
import '../../../../service/storage_service.dart';
import 'grid_base_page_service_mixin.dart';
import 'grid_base_page_state.dart';

abstract class GridBasePageLogic extends GetxController with Scroll2TopLogicMixin {
  final String bodyId = 'bodyId';

  @override
  GridBasePageState get state;

  GridBasePageServiceMixin get galleryService;

  final StorageService storageService = Get.find<StorageService>();

  void enterGroup(String group) {
    state.currentGroup = group;
    update([bodyId]);
  }

  void backGroup() {
    state.currentGroup = LocalGalleryService.rootPath;
    update([bodyId]);
  }
}
