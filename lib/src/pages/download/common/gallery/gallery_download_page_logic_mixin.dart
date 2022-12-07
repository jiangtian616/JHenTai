import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../../../../database/database.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../service/storage_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/process_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_download_dialog.dart';

mixin GalleryDownloadPageLogicMixin on GetxController {
  final String bodyId = 'bodyId';
  final String groupId = 'groupId';

  final GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
  final StorageService storageService = Get.find<StorageService>();

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

    return doRenameGroup(oldGroup, newGroup);
  }

  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
    await downloadService.renameGroup(oldGroup, newGroup);
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
    downloadService.update([downloadService.galleryCountOrOrderChangedId]);
  }

  void handleAssignPriority(GalleryDownloadedData gallery, int? priority) {
    downloadService.assignPriority(gallery, priority);
    updateSafely([bodyId]);
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
          galleryTitle: gallery.title,
          galleryUrl: gallery.galleryUrl,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: gallery.pageCount,
        ),
      );
    }
  }

  void showBottomSheet(GalleryDownloadedData gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('changeGroup'.tr),
            onPressed: () {
              backRoute();
              handleChangeGroup(gallery);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('changePriority'.tr),
            onPressed: () {
              backRoute();
              showPrioritySheet(gallery, context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('reDownload'.tr),
            onPressed: () {
              handleReDownloadItem(context, gallery);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('deleteTask'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              handleRemoveItem(gallery, false);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('deleteTaskAndImages'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              handleRemoveItem(gallery, true);
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

  void showPrioritySheet(GalleryDownloadedData gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 1 (${'highest'.tr})'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 1,
            onPressed: () {
              handleAssignPriority(gallery, 1);
              backRoute();
            },
          ),
          ...[2, 3]
              .map((i) => CupertinoActionSheetAction(
                    child: Text('${'priority'.tr} : $i'),
                    isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == i,
                    onPressed: () {
                      handleAssignPriority(gallery, i);
                      backRoute();
                    },
                  ))
              .toList(),
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 4 (${'default'.tr})'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 4,
            onPressed: () {
              handleAssignPriority(gallery, 4);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 5'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 5,
            onPressed: () {
              handleAssignPriority(gallery, 5);
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
}
