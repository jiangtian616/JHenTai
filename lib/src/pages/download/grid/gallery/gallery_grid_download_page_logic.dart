import 'dart:math';

import 'package:jhentai/src/pages/download/grid/base/grid_base_page_service_mixin.dart';

import '../../../../database/database.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download_service.dart';
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

  void goToDetailPage(GalleryDownloadedData gallery) {
    toRoute(Routes.details, arguments: {'galleryUrl': gallery.galleryUrl});
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex) async {
    List<GalleryDownloadedData> gallerys = state.currentGalleryObjects.cast();

    int head = min(beforeIndex, afterIndex);
    int tail = max(beforeIndex, afterIndex);

    for (int index = head; index <= tail; index++) {
      GalleryDownloadInfo galleryDownloadInfo = downloadService.galleryDownloadInfos[gallerys[index].gid]!;

      if (index == beforeIndex) {
        galleryDownloadInfo.sortOrder = afterIndex;
      } else if (beforeIndex < afterIndex) {
        galleryDownloadInfo.sortOrder = index - 1;
      } else {
        galleryDownloadInfo.sortOrder = index + 1;
      }
    }

    await downloadService.updateGalleryOrder(gallerys.sublist(head, tail + 1));
  }

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) async {
    return downloadService.updateGroupOrder(beforeIndex, afterIndex);
  }
}
