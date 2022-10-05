import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/utils/process_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';

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

  @override
  void onInit() {
    super.onInit();
    state.displayGroups = Set.from(storageService.read('displayGalleryGroups') ?? []);
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

    Map<String, dynamic>? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        currentGroup: oldGroup,
        candidates: downloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result['group'] ?? 'default'.tr;
    if (newGroup == oldGroup) {
      return;
    }

    await downloadService.updateGroup(gallery, newGroup);

    update([bodyId]);
  }

  Future<void> handleLongPressGroup(String oldGroup) async {
    if (downloadService.galleryDownloadInfos.values.every((g) => g.group != oldGroup)) {
      return handleDeleteGroup(oldGroup);
    }
    return handleRenameGroup(oldGroup);
  }

  Future<void> handleRenameGroup(String oldGroup) async {
    Map<String, dynamic>? result = await Get.dialog(
      EHDownloadDialog(
        title: 'renameGroup'.tr,
        currentGroup: oldGroup,
        candidates: downloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result['group'] ?? 'default'.tr;
    if (newGroup == oldGroup) {
      return;
    }

    await downloadService.renameGroup(oldGroup, newGroup);

    state.displayGroups.remove(oldGroup);
    state.displayGroups.add(newGroup);

    update([bodyId]);
  }

  Future<void> handleDeleteGroup(String oldGroup) async {
    bool? success = await Get.dialog(EHAlertDialog(title: 'deleteGroup'.tr + '?'));
    if (success == null || !success) {
      return;
    }

    await downloadService.deleteGroup(oldGroup);

    update([bodyId]);
  }

  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages) {
    if (deleteImages) {
      state.removedGids.add(gallery.gid);
    } else {
      state.removedGidsWithoutImages.add(gallery.gid);
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
    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(downloadService.computeGalleryDownloadPath(gallery.title, gallery.gid));
    } else {
      String storageKey = 'readIndexRecord::${gallery.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.downloaded,
          gid: gallery.gid,
          galleryUrl: gallery.galleryUrl,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: gallery.pageCount,
        ),
      );
    }
  }
}
