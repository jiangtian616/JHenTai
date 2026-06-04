import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_logic_mixin.dart';
import 'package:jhentai/src/setting/performance_setting.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../mixin/update_global_gallery_status_logic_mixin.dart';
import '../../../../service/local_config_service.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'gallery_list_download_page_state.dart';

class GalleryListDownloadPageLogic extends GetxController
    with Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<GalleryDownloadedData>, GalleryDownloadPageLogicMixin, UpdateGlobalGalleryStatusLogicMixin {
  GalleryListDownloadPageState state = GalleryListDownloadPageState();

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  late Worker maxGalleryNum4AnimationListener;

  @override
  Future<void> onInit() async {
    super.onInit();

    String? displayGroupsString = await localConfigService.read(configKey: ConfigEnum.displayGalleryGroups);
    if (displayGroupsString == null) {
      state.displayGroups = {'default'.tr};
    } else {
      state.displayGroups = Set.from(jsonDecode(displayGroupsString));
    }
    state.displayGroupsCompleter.complete();

    maxGalleryNum4AnimationListener = ever(performanceSetting.maxGalleryNum4Animation, (_) => updateSafely([bodyId]));

    // Load images for all galleries to support lazy loading from earlier memory fix
    _loadGalleryImages();
  }

  /// Load images for all galleries to support lazy loading
  Future<void> _loadGalleryImages() async {
    for (final gallery in downloadService.gallerys) {
      if (!downloadService.areGalleryImagesLoaded(gallery.gid)) {
        await downloadService.ensureGalleryImagesLoaded(gallery.gid);
        // Trigger UI update for this gallery's image
        downloadService.update(['${downloadService.downloadImageUrlId}::${gallery.gid}::0']);
      }
    }
  }

  @override
  void onClose() {
    super.onClose();

    maxGalleryNum4AnimationListener.dispose();
  }

  Future<void> toggleDisplayGroups(String groupName) async {
    await state.displayGroupsCompleter.future;

    if (state.displayGroups.contains(groupName)) {
      state.displayGroups.remove(groupName);
    } else {
      state.displayGroups.add(groupName);
    }

    await localConfigService.write(configKey: ConfigEnum.displayGalleryGroups, value: jsonEncode(state.displayGroups.toList()));
    state.groupedListController.toggleGroup(groupName);
  }

  @override
  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
    await state.displayGroupsCompleter.future;

    state.displayGroups.remove(oldGroup);
    return super.doRenameGroup(oldGroup, newGroup);
  }

  @override
  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages, BuildContext context) async {
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

    state.groupedListController.removeElement(gallery).then((_) {
      state.selectedGids.remove(gallery.gid);
      downloadService.deleteGallery(gallery, deleteImages: deleteImages);
      updateGlobalGalleryStatus();
    });
  }

  @override
  Future<void> selectAllItem() async {
    await state.displayGroupsCompleter.future;

    List<GalleryDownloadedData> gallerys = [];
    for (String group in state.displayGroups) {
      gallerys.addAll(downloadService.gallerysWithGroup(group));
    }

    multiSelectDownloadPageState.selectedGids.addAll(gallerys.map((gallery) => gallery.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids.map((gid) => '$itemCardId::$gid').toList());
  }
}
