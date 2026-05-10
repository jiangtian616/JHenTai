import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/mixin/update_global_gallery_status_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_logic_mixin.dart';

import '../../../../database/database.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'gallery_category_list_download_page_state.dart';

class GalleryCategoryListDownloadPageLogic extends GetxController
    with
        Scroll2TopLogicMixin,
        MultiSelectDownloadPageLogicMixin<GalleryDownloadedData>,
        GalleryDownloadPageLogicMixin,
        UpdateGlobalGalleryStatusLogicMixin {
  GalleryCategoryListDownloadPageState state =
      GalleryCategoryListDownloadPageState();

  final TextEditingController authorFilterController = TextEditingController();

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  Future<void> onInit() async {
    super.onInit();

    state.knownGroups.addAll(downloadService.authorGroups);
    state.displayGroups.addAll(downloadService.authorGroups);
    state.displayGroupsCompleter.complete();
  }

  Future<void> toggleDisplayGroups(String groupName) async {
    await state.displayGroupsCompleter.future;

    if (state.displayGroups.contains(groupName)) {
      state.displayGroups.remove(groupName);
    } else {
      state.displayGroups.add(groupName);
    }

    state.groupedListController.toggleGroup(groupName);
  }

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

    state.selectedGids.remove(gallery.gid);
    downloadService.deleteGallery(gallery, deleteImages: deleteImages);
    updateGlobalGalleryStatus();
  }

  @override
  Future<void> selectAllItem() async {
    await state.displayGroupsCompleter.future;

    List<GalleryDownloadedData> gallerys = [];
    for (String group in state.filteredAuthorGroups
        .where((group) => state.displayGroups.contains(group))) {
      gallerys.addAll(downloadService.gallerysWithAuthor(group));
    }

    multiSelectDownloadPageState.selectedGids
        .addAll(gallerys.map((gallery) => gallery.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids
        .map((gid) => '$itemCardId::$gid')
        .toList());
  }

  Map<String, bool> getAuthorGroupOpenStates() {
    for (String group in state.filteredAuthorGroups) {
      if (state.knownGroups.add(group)) {
        state.displayGroups.add(group);
      }
    }
    return Map.fromEntries(state.filteredAuthorGroups
        .map((group) => MapEntry(group, state.displayGroups.contains(group))));
  }

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
