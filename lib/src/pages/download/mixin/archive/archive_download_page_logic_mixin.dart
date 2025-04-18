import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/mixin/update_global_gallery_status_logic_mixin.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';

import '../../../../database/database.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../service/local_config_service.dart';
import '../../../../service/super_resolution_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/process_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/toast_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_download_dialog.dart';
import '../../../../widget/re_unlock_dialog.dart';
import '../basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'archive_download_page_state_mixin.dart';

mixin ArchiveDownloadPageLogicMixin on GetxController
    implements Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<ArchiveDownloadedData>, UpdateGlobalGalleryStatusLogicMixin {
  final String bodyId = 'bodyId';

  ArchiveDownloadPageStateMixin get archiveDownloadPageState;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => archiveDownloadPageState;

  Future<void> handleChangeArchiveGroup(ArchiveDownloadedData archive) async {
    String oldGroup = archiveDownloadService.archiveDownloadInfos[archive.gid]!.group;

    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        currentGroup: oldGroup,
        candidates: archiveDownloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;
    if (newGroup == oldGroup) {
      return;
    }

    await archiveDownloadService.updateArchiveGroup(archive.gid, newGroup);
    update([bodyId]);
  }

  @override
  void handleTapItem(ArchiveDownloadedData item) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(item.gid);
    } else {
      goToReadPage(item);
    }
  }

  @override
  void handleLongPressOrSecondaryTapItem(ArchiveDownloadedData item, BuildContext context) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(item.gid);
    } else {
      showBottomSheet(item, context);
    }
  }

  Future<void> handleLongPressGroup(String groupName) {
    if (archiveDownloadService.archiveDownloadInfos.values.every((a) => a.group != groupName)) {
      return handleDeleteGroup(groupName);
    }
    return handleRenameGroup(groupName);
  }

  Future<void> handleRenameGroup(String oldGroup) async {
    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'renameGroup'.tr,
        currentGroup: oldGroup,
        candidates: archiveDownloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;
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
    bool? success = await Get.dialog(EHDialog(title: 'deleteGroup'.tr + '?'));
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

  Future<void> goToReadPage(ArchiveDownloadedData archive) async {
    if (archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
      return;
    }

    if (readSetting.useThirdPartyViewer.isTrue && readSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(archiveDownloadService.computeArchiveUnpackingPath(archive.title, archive.gid));
    } else {
      String? string = await localConfigService.read(configKey: ConfigEnum.readIndexRecord, subConfigKey: archive.gid.toString());
      int readIndexRecord = (string == null ? 0 : (int.tryParse(string) ?? 0));

      List<GalleryImage> images = await archiveDownloadService.getUnpackedImages(archive.gid);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          galleryTitle: archive.title,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
          pageCount: images.length,
          isOriginal: archive.isOriginal,
          readProgressRecordStorageKey: archive.gid.toString(),
          images: images,
          useSuperResolution: superResolutionService.get(archive.gid, SuperResolutionType.archive) != null,
        ),
      );
    }
  }

  void showBottomSheet(ArchiveDownloadedData archive, BuildContext context) {
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid];

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          if (superResolutionSetting.modelDirectoryPath.value != null &&
              (superResolutionService.get(archive.gid, SuperResolutionType.archive) == null ||
                  superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.paused))
            CupertinoActionSheetAction(
              child: Text('superResolution'.tr),
              onPressed: () async {
                backRoute();

                if (superResolutionService.get(archive.gid, SuperResolutionType.archive) == null && archive.isOriginal) {
                  bool? result = await Get.dialog(EHDialog(title: 'attention'.tr + '!', content: 'superResolveOriginalImageHint'.tr));
                  if (result == false) {
                    return;
                  }
                }

                superResolutionService.superResolve(archive.gid, SuperResolutionType.archive);
              },
            ),
          if (superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.running)
            CupertinoActionSheetAction(
              child: Text('stopSuperResolution'.tr),
              onPressed: () async {
                backRoute();

                superResolutionService.pauseSuperResolve(archive.gid, SuperResolutionType.archive).then((_) => toast("success".tr));
              },
            ),
          if (superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.paused ||
              superResolutionService.get(archive.gid, SuperResolutionType.archive)?.status == SuperResolutionStatus.success)
            CupertinoActionSheetAction(
              child: Text('deleteSuperResolvedImage'.tr),
              onPressed: () async {
                backRoute();

                superResolutionService.deleteSuperResolve(archive.gid, SuperResolutionType.archive).then((_) => toast("success".tr));
              },
            ),
          if (archiveDownloadInfo != null &&
              archiveDownloadInfo.archiveStatus.code < ArchiveStatus.downloaded.code &&
              archiveDownloadInfo.parseSource == ArchiveParseSource.bot.code)
            CupertinoActionSheetAction(
              child: Text('changeParseSource2Official'.tr),
              onPressed: () {
                backRoute();
                handleChangeParseSource(archive.gid, ArchiveParseSource.official);
              },
            ),
          if (archiveDownloadInfo != null &&
              archiveDownloadInfo.archiveStatus.code < ArchiveStatus.downloaded.code &&
              archiveBotSetting.apiKey.value != null &&
              archiveDownloadInfo.parseSource == ArchiveParseSource.official.code)
            CupertinoActionSheetAction(
              child: Text('changeParseSource2Bot'.tr),
              onPressed: () {
                backRoute();
                handleChangeParseSource(archive.gid, ArchiveParseSource.bot);
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
      await archiveDownloadService.cancelArchive(archive.gid);
      await archiveDownloadService.downloadArchive(archive, resume: true);
    }
  }

  Future<void> handleMultiResumeTasks() async {
    for (int gid in multiSelectDownloadPageState.selectedGids) {
      archiveDownloadService.resumeDownloadArchive(gid);
    }

    exitSelectMode();
  }

  Future<void> handleMultiPauseTasks() async {
    for (int gid in multiSelectDownloadPageState.selectedGids) {
      archiveDownloadService.pauseDownloadArchive(gid);
    }

    exitSelectMode();
  }

  Future<void> handleMultiChangeGroup() async {
    ({String group, bool downloadOriginalImage})? result = await Get.dialog(
      EHDownloadDialog(
        title: 'changeGroup'.tr,
        candidates: archiveDownloadService.allGroups,
      ),
    );

    if (result == null) {
      return;
    }

    String newGroup = result.group;

    for (int gid in multiSelectDownloadPageState.selectedGids) {
      await archiveDownloadService.updateArchiveGroup(gid, newGroup);
    }

    multiSelectDownloadPageState.inMultiSelectMode = false;
    multiSelectDownloadPageState.selectedGids.clear();
    updateSafely([bottomAppbarId, bodyId]);
  }

  Future<void> handleMultiDelete() async {
    bool? result = await Get.dialog(
      EHDialog(title: 'delete'.tr, content: 'multiDeleteHint'.tr),
    );

    if (result == true) {
      for (int gid in multiSelectDownloadPageState.selectedGids) {
        archiveDownloadService.deleteArchive(gid);
      }

      exitSelectMode();
      updateGlobalGalleryStatus();
    }
  }

  Future<void> handleChangeParseSource(int gid, ArchiveParseSource parseSource) async {
    return archiveDownloadService.changeParseSource(gid, parseSource);
  }
}
