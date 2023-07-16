import 'dart:math';

import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';

import '../../../../database/database.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/toast_util.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../../mixin/gallery/gallery_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_service_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';
import 'gallery_grid_download_page_state.dart';

class GalleryGridDownloadPageLogic extends GetxController
    with Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<GalleryDownloadedData>, GalleryDownloadPageLogicMixin, GridBasePageLogic {
  GalleryGridDownloadPageState state = GalleryGridDownloadPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  GridBasePageState get gridBasePageState => state;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  GridBasePageServiceMixin get galleryService => downloadService;

  void handleTapTitle(GalleryDownloadedData gallery) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(gallery.gid);
    } else {
      goToDetailPage(gallery);
    }
  }

  @override
  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages) {
    downloadService.deleteGallery(gallery, deleteImages: deleteImages).then((_) => super.handleRemoveItem(gallery, deleteImages));
  }

  void goToDetailPage(GalleryDownloadedData gallery) {
    toRoute(
      Routes.details,
      arguments: {'gid': gallery.gid, 'galleryUrl': gallery.galleryUrl},
    );
  }

  @override
  void toggleEditMode() {
    if (!gridBasePageState.inEditMode) {
      exitSelectMode();
      toast('drag2sort'.tr);
    }
    gridBasePageState.inEditMode = !gridBasePageState.inEditMode;
    update([bodyId, editButtonId]);
  }

  @override
  void selectAllItem() {
    multiSelectDownloadPageState.selectedGids.clear();
    multiSelectDownloadPageState.selectedGids.addAll(state.currentGalleryObjects.map((archive) => archive.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids.map((gid) => '$itemCardId::$gid').toList());
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex) async {
    List<GalleryDownloadedData> gallerys = state.currentGalleryObjects.cast();

    /// default order is 0, we must assign current order to the archive first
    for (int i = 0; i < gallerys.length; i++) {
      GalleryDownloadedData gallery = gallerys[i];
      GalleryDownloadInfo galleryDownloadInfo = downloadService.galleryDownloadInfos[gallery.gid]!;
      galleryDownloadInfo.sortOrder = i;
    }

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

    await downloadService.updateGalleryOrder(gallerys);
  }

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) async {
    return downloadService.updateGroupOrder(beforeIndex, afterIndex);
  }
}
