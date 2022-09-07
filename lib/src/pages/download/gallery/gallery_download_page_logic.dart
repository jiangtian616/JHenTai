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

  final Map<int, AnimationController> removedGid2AnimationController = {};
  final Map<int, Animation<double>> removedGid2Animation = {};

  @override
  void onInit() {
    state.displayGroups = Set.from(storageService.read('displayGalleryGroups') ?? ['default'.tr]);
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();

    for (AnimationController controller in removedGid2AnimationController.values) {
      controller.dispose();
    }
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

  void handleRemoveItem(BuildContext context, GalleryDownloadedData gallery, bool deleteImages) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedGid2AnimationController.remove(gallery.gid);
        removedGid2Animation.remove(gallery.gid);

        Get.engine.addPostFrameCallback((_) {
          downloadService.deleteGallery(gallery, deleteImages: deleteImages);
        });
      }
    });
    removedGid2AnimationController[gallery.gid] = controller;
    removedGid2Animation[gallery.gid] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));

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
