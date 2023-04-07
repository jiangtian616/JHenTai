import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../../../../database/database.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../service/storage_service.dart';
import '../../../../service/super_resolution_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/process_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_download_dialog.dart';
import '../../../../widget/re_unlock_dialog.dart';

mixin ArchiveDownloadPageLogicMixin on GetxController {
  final String bodyId = 'bodyId';
  final String groupId = 'groupId';

  final ArchiveDownloadService archiveDownloadService = Get.find();
  final SuperResolutionService superResolutionService = Get.find();
  final StorageService storageService = Get.find();

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

    await archiveDownloadService.updateArchiveGroup(archive, newGroup);
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

    return doRenameGroup(oldGroup, newGroup);
  }

  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
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

  void handleResumeAllTasks() {
    archiveDownloadService.resumeAllDownloadArchive();
  }

  void handlePauseAllTasks() {
    archiveDownloadService.pauseAllDownloadArchive();
  }

  void handleRemoveItem(ArchiveDownloadedData archive) {
    archiveDownloadService.update([archiveDownloadService.galleryCountChangedId]);
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
      List<GalleryImage> images = archiveDownloadService.getUnpackedImages(archive.gid);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          galleryTitle: archive.title,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          pageCount: images.length,
          isOriginal: archive.isOriginal,
          readProgressRecordStorageKey: storageKey,
          images: images,
          useSuperResolution: superResolutionService.get(archive.gid, SuperResolutionType.archive) != null,
        ),
      );
    }
  }

  void showArchiveBottomSheet(ArchiveDownloadedData archive, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          if (SuperResolutionSetting.modelDirectoryPath.value != null)
            CupertinoActionSheetAction(
              child: Text(
                superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.running
                    ? 'stopSuperResolution'.tr
                    : superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.success
                        ? 'deleteSuperResolvedImage'.tr
                        : 'superResolution'.tr,
              ),
              onPressed: () async {
                backRoute();
                if (superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.running) {
                  superResolutionService.pauseSuperResolve(archive.gid, SuperResolutionType.archive);
                } else if (superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.success) {
                  superResolutionService.deleteSuperResolutionInfo(archive.gid, SuperResolutionType.archive);
                } else {
                  if (archive.isOriginal) {
                    bool? result = await Get.dialog(EHAlertDialog(title: 'attention'.tr + '!', content: 'superResolveOriginalImageHint'.tr));
                    if (result == false) {
                      return;
                    }
                  }
                  superResolutionService.superResolve(archive.gid, SuperResolutionType.gallery);
                }
              },
            ),
          CupertinoActionSheetAction(
            child: Text('changeGroup'.tr),
            onPressed: () {
              backRoute();
              handleChangeArchiveGroup(archive);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
            onPressed: () {
              handleRemoveItem(archive);
              backRoute();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: backRoute,
        ),
      ),
    );
  }

  Future<void> handleReUnlockArchive(ArchiveDownloadedData archive) async {
    bool? ok = await Get.dialog(const ReUnlockDialog());
    if (ok ?? false) {
      archiveDownloadService.cancelUnlockArchiveAndDownload(archive);
    }
  }
}
