import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../service/local_gallery_service.dart';
import '../../mixin/local/local_gallery_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_service_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';
import 'local_gallery_grid_page_state.dart';

class LocalGalleryGridPageLogic extends GetxController with Scroll2TopLogicMixin, GridBasePageLogic, LocalGalleryDownloadPageLogicMixin {
  LocalGalleryGridPageState state = LocalGalleryGridPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  GridBasePageState get gridBasePageState => state;

  @override
  GridBasePageServiceMixin get galleryService => localGalleryService;

  @override
  String get currentPath => state.currentGroup;

  @override
  set currentPath(String value) => state.currentGroup = value;

  @override
  void backGroup() {
    backRoute();
  }

  @override
  Future<void> doRemoveItem(LocalGallery gallery) async {
    localGalleryService.deleteGallery(gallery, currentPath);
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex) async {}

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) async {}

  @override
  void handlePauseAllTasks() {}

  @override
  void handleResumeAllTasks() {}
}
