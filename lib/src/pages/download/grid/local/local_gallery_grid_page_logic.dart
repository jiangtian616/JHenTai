import 'package:jhentai/src/pages/download/grid/base/grid_base_page_logic.dart';
import 'package:jhentai/src/pages/download/grid/base/grid_base_page_service_mixin.dart';
import '../../../../service/local_gallery_service.dart';
import '../../common/local/local_gallery_download_page_logic_mixin.dart';
import 'local_gallery_grid_page_state.dart';

class LocalGalleryGridPageLogic extends GridBasePageLogic with LocalGalleryDownloadPageLogicMixin {
  @override
  LocalGalleryGridPageState state = LocalGalleryGridPageState();

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
    super.doRemoveItem(gallery);
  }
}
