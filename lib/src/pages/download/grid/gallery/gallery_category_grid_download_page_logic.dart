import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/mixin/update_global_gallery_status_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';

import '../../../../database/database.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../../mixin/gallery/gallery_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_service_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';
import 'gallery_category_grid_download_page_state.dart';

class GalleryCategoryGridDownloadPageLogic extends GetxController
    with
        Scroll2TopLogicMixin,
        MultiSelectDownloadPageLogicMixin<GalleryDownloadedData>,
        GalleryDownloadPageLogicMixin,
        GridBasePageLogic,
        UpdateGlobalGalleryStatusLogicMixin {
  GalleryCategoryGridDownloadPageState state =
      GalleryCategoryGridDownloadPageState();

  final TextEditingController authorFilterController = TextEditingController();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  GridBasePageState get gridBasePageState => state;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  GridBasePageServiceMixin get galleryService => downloadService;

  @override
  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages,
      BuildContext context) async {
    bool isUpdatingDependent = downloadService.isUpdatingDependent(gallery.gid);

    if (isUpdatingDependent) {
      bool? result = await showDialog(
        context: context,
        builder: (_) => EHDialog(
          title: 'delete'.tr + '?',
          content: 'deleteUpdatingDependentHint'.tr,
        ),
      );
      if (result == null || !result) {
        return;
      }
    }

    downloadService
        .deleteGallery(gallery, deleteImages: deleteImages)
        .then((_) => super.handleRemoveItem(gallery, deleteImages, context));
  }

  @override
  Future<void> selectAllItem() async {
    multiSelectDownloadPageState.selectedGids.clear();
    multiSelectDownloadPageState.selectedGids.addAll(state.currentGalleryObjects
        .cast<GalleryDownloadedData>()
        .map((gallery) => gallery.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids
        .map((gid) => '$itemCardId::$gid')
        .toList());
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(
      int beforeIndex, int afterIndex) async {}

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) async {}

  @override
  void toggleEditMode() {}

  void updateAuthorFilterKeyword(String keyword) {
    state.authorFilterKeyword = keyword;
    updateSafely([bodyId]);
  }

  @override
  void onClose() {
    authorFilterController.dispose();
    super.onClose();
  }
}
