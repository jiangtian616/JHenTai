import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../database/database.dart';
import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/gallery_download_service.dart';
import '../../../service/storage_service.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_download_dialog.dart';
import 'gallery_download_page_state.dart';

class GalleryDownloadPageLogic extends GetxController with GetTickerProviderStateMixin, Scroll2TopLogicMixin {
  static const String bodyId = 'pageId';
  static const String groupId = 'groupId';

  @override
  GalleryDownloadPageState state = GalleryDownloadPageState();

  final GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
  final StorageService storageService = Get.find<StorageService>();

  final Set<String> removedGroups = {};
  final Set<int> removedGids = {};
  final Set<int> removedGidsWithoutImages = {};

  @override
  void onInit() {
    super.onInit();
    state.displayGroups = Set.from(storageService.read('displayGalleryGroups') ?? ['default'.tr]);
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();
  }

  void toggleDisplayGroups(String groupName) {
    if (state.displayGroups.contains(groupName)) {
      state.displayGroups.remove(groupName);
    } else {
      state.displayGroups.add(groupName);
    }

    storageService.write('displayGalleryGroups', state.displayGroups.toList());
    update(['$groupId::$groupName']);
  }

  Future<void> handleChangeGroup(GalleryDownloadedData gallery) async {
    String oldGroup = downloadService.galleryDownloadInfos[gallery.gid]!.group;

    String? newGroup = await Get.dialog(EHDownloadDialog(
      candidates: downloadService.allGroups.toList(),
      currentGroup: oldGroup,
    ));
    if (newGroup == null) {
      return;
    }

    if (newGroup == oldGroup) {
      return;
    }

    await downloadService.updateGalleryGroup(gallery, newGroup);
    update([bodyId]);
  }

  Future<void> handleRenameGroup(String oldGroupName) async {
    String? newGroup = await Get.dialog(EHDownloadDialog(
      candidates: downloadService.allGroups.toList(),
      currentGroup: oldGroupName,
    ));
    if (newGroup == null) {
      return;
    }

    if (newGroup == oldGroupName) {
      return;
    }

    await downloadService.renameGroupName(oldGroupName, newGroup);

    state.displayGroups.remove(oldGroupName);
    state.displayGroups.add(newGroup);

    update([bodyId]);
  }

  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages) {
    if (deleteImages) {
      removedGids.add(gallery.gid);
    } else {
      removedGidsWithoutImages.add(gallery.gid);
    }

    String group = downloadService.galleryDownloadInfos[gallery.gid]!.group;
    if(downloadService.galleryDownloadInfos.values.every((g) => g.group != group)) {
      removedGroups.add(group);
    }

    downloadService.update([galleryCountOrOrderChangedId]);
  }

  void handleAssignPriority(GalleryDownloadedData gallery, int? priority) {
    downloadService.assignPriority(gallery, priority);
  }

  void handleReDownloadItem(BuildContext context, GalleryDownloadedData gallery) {
    downloadService.reDownloadGallery(gallery);
  }

  void goToReadPage(GalleryDownloadedData gallery) {
    int readIndexRecord = storageService.read('readIndexRecord::${gallery.gid}') ?? 0;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.downloaded,
        gid: gallery.gid,
        galleryUrl: gallery.galleryUrl,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: gallery.pageCount,
      ),
    );
  }
}
