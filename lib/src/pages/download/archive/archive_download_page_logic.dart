import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_download_dialog.dart';

import '../../../database/database.dart';
import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../model/gallery_image.dart';
import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/archive_download_service.dart';
import '../../../service/storage_service.dart';
import '../../../utils/route_util.dart';
import 'archive_download_page_state.dart';

class ArchiveDownloadPageLogic extends GetxController with GetTickerProviderStateMixin, Scroll2TopLogicMixin {
  static const String bodyId = 'pageId';
  static const String groupId = 'groupId';

  @override
  ArchiveDownloadPageState state = ArchiveDownloadPageState();

  final ArchiveDownloadService archiveDownloadService = Get.find();
  final StorageService storageService = Get.find();

  final Map<int, AnimationController> removedGidAndIsOrigin2AnimationController = {};
  final Map<int, Animation<double>> removedGidAndIsOrigin2Animation = {};

  @override
  void onInit() {
    state.displayGroups = Set.from(storageService.read('displayArchiveGroups') ?? ['default'.tr]);
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();

    for (AnimationController controller in removedGidAndIsOrigin2AnimationController.values) {
      controller.dispose();
    }
  }

  void toggleDisplayGroups(String groupName) {
    if (state.displayGroups.contains(groupName)) {
      state.displayGroups.remove(groupName);
    } else {
      state.displayGroups.add(groupName);
    }

    storageService.write('displayArchiveGroups', state.displayGroups.toList());
    update(['$groupId::$groupName']);
  }

  Future<void> handleChangeArchiveGroup(ArchiveDownloadedData archive) async {
    String oldGroup = archiveDownloadService.archiveDownloadInfos[archive.gid]!.group;

    String? newGroup = await Get.dialog(EHDownloadDialog(
      candidates: archiveDownloadService.allGroups.toList(),
      currentGroup: oldGroup,
    ));
    if (newGroup == null) {
      return;
    }

    if (newGroup == oldGroup) {
      return;
    }

    await archiveDownloadService.updateArchiveGroup(archive, newGroup);
    update([bodyId]);
  }

  Future<void> handleRenameGroup(String oldGroupName) async {
    String? newGroup = await Get.dialog(EHDownloadDialog(
      candidates: archiveDownloadService.allGroups.toList(),
      currentGroup: oldGroupName,
    ));
    if (newGroup == null) {
      return;
    }

    if (newGroup == oldGroupName) {
      return;
    }

    await archiveDownloadService.renameGroupName(oldGroupName, newGroup);
    update([bodyId]);
  }

  void handleRemoveItem(ArchiveDownloadedData archive) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedGidAndIsOrigin2AnimationController.remove(archive.gid);
        removedGidAndIsOrigin2Animation.remove(archive.gid);

        Get.engine.addPostFrameCallback((_) {
          archiveDownloadService.deleteArchive(archive);
        });
      }
    });
    removedGidAndIsOrigin2AnimationController[archive.gid] = controller;
    removedGidAndIsOrigin2Animation[archive.gid] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));

    archiveDownloadService.update([ArchiveDownloadService.archiveCountChangedId]);
  }

  void goToReadPage(ArchiveDownloadedData archive) {
    if (archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
      return;
    }

    int readIndexRecord = storageService.read('readIndexRecord::${archive.gid}') ?? 0;
    List<GalleryImage> images = archiveDownloadService.getUnpackedImages(archive);

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.archive,
        gid: archive.gid,
        galleryUrl: archive.galleryUrl,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: images.length,
        isOriginal: archive.isOriginal,
        images: images,
      ),
    );
  }
}
