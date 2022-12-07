import 'package:jhentai/src/pages/download/grid/base/grid_base_page_service_mixin.dart';

import '../../../../database/database.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../../common/gallery/gallery_download_page_logic_mixin.dart';
import '../base/grid_base_page_logic.dart';
import 'gallery_grid_download_page_state.dart';

class GalleryGridDownloadPageLogic extends GridBasePageLogic with GalleryDownloadPageLogicMixin {
  @override
  GalleryGridDownloadPageState state = GalleryGridDownloadPageState();

  @override
  GridBasePageServiceMixin get galleryService => downloadService;

  @override
  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages) {
    downloadService.deleteGallery(gallery, deleteImages: deleteImages).then((_) => super.handleRemoveItem(gallery, deleteImages));
  }

  void goToDetailPage(int index) {
    toRoute(Routes.details, arguments: {'galleryUrl': state.currentGalleryObjects[index].galleryUrl});
  }
}
