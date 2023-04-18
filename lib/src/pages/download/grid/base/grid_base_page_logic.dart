import 'package:get/get.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../service/local_gallery_service.dart';
import '../../../../service/storage_service.dart';
import '../../../../service/super_resolution_service.dart';
import 'grid_base_page_service_mixin.dart';
import 'grid_base_page_state.dart';

abstract class GridBasePageLogic extends GetxController with Scroll2TopLogicMixin {
  final String bodyId = 'bodyId';
  final String editButtonId = 'editButtonId';

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
    update([bodyId, editButtonId]);
  }

  void toggleEditMode() {
    if (!state.inEditMode) {
      toast('drag2sort'.tr);
    }
    state.inEditMode = !state.inEditMode;
    update([bodyId, editButtonId]);
  }

  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex);

  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex);

  void handleResumeAllTasks();

  void handlePauseAllTasks();
}
