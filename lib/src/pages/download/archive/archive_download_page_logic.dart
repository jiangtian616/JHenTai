import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_download_dialog.dart';

import '../../../database/database.dart';
import '../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../model/gallery_image.dart';
import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/archive_download_service.dart';
import '../../../service/storage_service.dart';
import '../../../setting/read_setting.dart';
import '../../../utils/process_util.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_alert_dialog.dart';
import 'archive_download_page_state.dart';

class ArchiveDownloadPageLogic extends GetxController with GetTickerProviderStateMixin, Scroll2TopLogicMixin {
  static const String bodyId = 'pageId';
  static const String groupId = 'groupId';

  @override
  ArchiveDownloadPageState state = ArchiveDownloadPageState();

  final ArchiveDownloadService archiveDownloadService = Get.find();
  final StorageService storageService = Get.find();

  @override
  void onInit() {
    state.displayGroups = Set.from(storageService.read('displayArchiveGroups') ?? ['default'.tr]);
    super.onInit();
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

    storageService.write('displayArchiveGroups', state.displayGroups.toList());
    update(['$groupId::$groupName']);
  }

  Future<void> handleChangeArchiveGroup(ArchiveDownloadedData archive) async {
    String oldGroup = archiveDownloadService.archiveDownloadInfos[archive.gid]!.group;

    Map<String, dynamic>? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        currentGroup: oldGroup,
        candidates: archiveDownloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result['group'] ?? 'default'.tr;
    if (newGroup == oldGroup) {
      return;
    }

    await archiveDownloadService.updateGroup(archive, newGroup);
    update([bodyId]);
  }

  Future<void> handleLongPressGroup(String groupName) {
    if (archiveDownloadService.archiveDownloadInfos.values.every((a) => a.group != groupName)) {
      return handleDeleteGroup(groupName);
    }
    return handleRenameGroup(groupName);
  }

  Future<void> handleRenameGroup(String oldGroup) async {
    Map<String, dynamic>? result = await Get.dialog(
      EHDownloadDialog(
        title: 'renameGroup'.tr,
        currentGroup: oldGroup,
        candidates: archiveDownloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result['group'] ?? 'default'.tr;
    if (newGroup == oldGroup) {
      return;
    }

    await archiveDownloadService.renameGroup(oldGroup, newGroup);
    update([bodyId]);
  }

  Future<void> handleDeleteGroup(String oldGroup) async {
    bool? success = await Get.dialog(EHAlertDialog(title: 'deleteGroup'.tr + '?'));
    if (success == null || !success) {
      return;
    }

    await archiveDownloadService.deleteGroup(oldGroup);

    update([bodyId]);
  }

  void handleRemoveItem(ArchiveDownloadedData archive) {
    state.removedGids.add(archive.gid);
    archiveDownloadService.update([ArchiveDownloadService.archiveCountChangedId]);
  }

  void goToReadPage(ArchiveDownloadedData archive) {
    if (archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
      return;
    }

    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(archiveDownloadService.computeArchiveUnpackingPath(archive));
    } else {
      String storageKey = 'readIndexRecord::${archive.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;
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
          readProgressRecordStorageKey: storageKey,
          images: images,
        ),
      );
    }
  }
}
