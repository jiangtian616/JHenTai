import 'dart:math';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_state_mixin.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';

import '../../../../model/gallery_image.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../utils/byte_util.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import '../mixin/grid_download_page_mixin.dart';
import 'archive_grid_download_page_logic.dart';
import 'archive_grid_download_page_state.dart';

class ArchiveGridDownloadPage extends StatelessWidget with Scroll2TopPageMixin, MultiSelectDownloadPageMixin, ArchiveDownloadPageMixin, GridBasePage {
  ArchiveGridDownloadPage({Key? key}) : super(key: key);

  @override
  final DownloadPageGalleryType galleryType = DownloadPageGalleryType.archive;
  @override
  final ArchiveGridDownloadPageLogic logic = Get.put<ArchiveGridDownloadPageLogic>(ArchiveGridDownloadPageLogic(), permanent: true);
  @override
  final ArchiveGridDownloadPageState state = Get.find<ArchiveGridDownloadPageLogic>().state;

  @override
  ArchiveDownloadPageLogicMixin get archiveDownloadPageLogic => logic;

  @override
  ArchiveDownloadPageStateMixin get archiveDownloadPageState => state;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      GetBuilder<ArchiveGridDownloadPageLogic>(
        global: false,
        init: logic,
        id: logic.editButtonId,
        builder: (_) => IconButton(
          icon: const Icon(Icons.sort),
          selectedIcon: const Icon(Icons.save),
          onPressed: logic.toggleEditMode,
          isSelected: state.inEditMode,
        ),
      ),
      PopupMenuButton(
        itemBuilder: (context) {
          return [
            PopupMenuItem(
              value: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.view_list), const SizedBox(width: 12), Text('switch2ListMode'.tr)],
              ),
            ),
            PopupMenuItem(
              value: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.done_all), const SizedBox(width: 12), Text('multiSelect'.tr)],
              ),
            ),
            PopupMenuItem(
              value: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.play_arrow), const SizedBox(width: 12), Text('resumeAllTasks'.tr)],
              ),
            ),
            PopupMenuItem(
              value: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.pause), const SizedBox(width: 12), Text('pauseAllTasks'.tr)],
              ),
            ),
          ];
        },
        onSelected: (value) {
          if (value == 0) {
            DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.list).dispatch(context);
          }
          if (value == 1) {
            if (state.inEditMode) {
              return;
            }
            logic.enterSelectMode();
          }
          if (value == 2) {
            logic.handleResumeAllTasks();
          }
          if (value == 3) {
            logic.handlePauseAllTasks();
          }
        },
      ),
    ];
  }

  @override
  Widget? buildGridBottomAppBar(BuildContext context) {
    return buildBottomAppBar();
  }

  @override
  GridGroup groupBuilder(BuildContext context, String groupName, bool inEditMode) {
    List<ArchiveDownloadedData> archives = state.galleryObjectsWithGroup(groupName);

    return GridGroup(
      groupName: groupName,
      widgets: archives
          .sublist(0, min(GridGroup.maxWidgetCount, archives.length))
          .map(
            (archive) => GetBuilder<ArchiveDownloadService>(
              id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
              builder: (_) {
                Widget cover = buildGroupInnerImage(GalleryImage(url: archive.coverUrl));

                if (logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus == ArchiveStatus.completed) {
                  return cover;
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Blur(
                    blur: 1,
                    blurColor: UIConfig.downloadPageGridCoverBlurColor,
                    colorOpacity: 0.6,
                    child: cover,
                    overlay: const Icon(Icons.download, color: UIConfig.downloadPageGridCoverOverlayColor),
                  ),
                );
              },
            ),
          )
          .toList(),
      onTap: inEditMode ? null : () => logic.enterGroup(groupName),
      onLongPress: inEditMode ? null : () => logic.handleLongPressGroup(groupName),
      onSecondTap: inEditMode ? null : () => logic.handleLongPressGroup(groupName),
    );
  }

  @override
  GridGallery galleryBuilder(BuildContext context, ArchiveDownloadedData archive, bool inEditMode) {
    return GridGallery(
      title: archive.title,
      widget: GetBuilder<ArchiveGridDownloadPageLogic>(
        id: '${logic.itemCardId}::${archive.gid}',
        builder: (_) => GetBuilder<ArchiveDownloadService>(
          id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
          builder: (_) {
            Widget cover = buildGalleryImage(GalleryImage(url: archive.coverUrl));

            if (logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus == ArchiveStatus.completed) {
              if (state.selectedGids.contains(archive.gid)) {
                return Stack(
                  children: [cover, _buildSelectedIcon()],
                );
              } else {
                return cover;
              }
            }

            ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Blur(
                    blur: 1,
                    blurColor: UIConfig.downloadPageGridCoverBlurColor,
                    colorOpacity: 0.6,
                    child: cover,
                  ),
                ),
                _buildCircularProgressIndicator(archive, archiveDownloadInfo),
                _buildDownloadProgress(archive, archiveDownloadInfo),
                _buildActionButton(archiveDownloadInfo, archive),
                if (state.selectedGids.contains(archive.gid)) _buildSelectedIcon(),
              ],
            );
          },
        ),
      ),
      isOriginal: archive.isOriginal,
      gid: archive.gid,
      superResolutionType: SuperResolutionType.archive,
      onTapWidget: inEditMode ? null : () => logic.handleTapItem(archive),
      onTapTitle: inEditMode ? null : () => logic.handleTapTitle(archive),
      onLongPress: inEditMode ? null : () => logic.handleLongPressOrSecondaryTapItem(archive, context),
      onSecondTap: inEditMode ? null : () => logic.handleLongPressOrSecondaryTapItem(archive, context),
      onTertiaryTap: inEditMode ? null : () => logic.handleTapTitle(archive),
    );
  }

  Widget _buildSelectedIcon() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: UIConfig.downloadPageGridViewSelectIconColor),
          color: UIConfig.downloadPageGridViewSelectIconBackGroundColor,
        ),
        child: const Icon(Icons.check, color: UIConfig.downloadPageGridViewSelectIconColor),
      ),
    );
  }

  Center _buildCircularProgressIndicator(ArchiveDownloadedData archive, ArchiveDownloadInfo archiveDownloadInfo) {
    return Center(
      child: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
        builder: (_) => ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: UIConfig.downloadPageGridViewCircularProgressSize,
            minHeight: UIConfig.downloadPageGridViewCircularProgressSize,
          ),
          child: CircularProgressIndicator(
            value: archiveDownloadInfo.speedComputer.downloadedBytes / archive.size,
            color: UIConfig.downloadPageGridProgressColor,
            backgroundColor: UIConfig.downloadPageGridProgressBackGroundColor,
          ),
        ),
      ),
    );
  }

  Center _buildDownloadProgress(ArchiveDownloadedData archive, ArchiveDownloadInfo archiveDownloadInfo) {
    return Center(
      child: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
        builder: (_) => Text(
          '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())} / ${byte2String(archive.size.toDouble())}',
          style: const TextStyle(fontSize: UIConfig.downloadPageGridViewInfoTextSize, color: UIConfig.downloadPageGridTextColor),
        ),
      ).marginOnly(top: 60),
    );
  }

  GestureDetector _buildActionButton(ArchiveDownloadInfo archiveDownloadInfo, ArchiveDownloadedData archive) {
    return GestureDetector(
      onTap: () => archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.needReUnlock.index
          ? logic.handleReUnlockArchive(archive)
          : archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
              ? logic.archiveDownloadService.resumeDownloadArchive(archive)
              : logic.archiveDownloadService.pauseDownloadArchive(archive),
      child: Center(
        child: GetBuilder<ArchiveDownloadService>(
          id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
          builder: (_) => archiveDownloadInfo.archiveStatus.index > ArchiveStatus.paused.index &&
                  archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index
              ? GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                  builder: (_) => Text(
                    archiveDownloadInfo.speedComputer.speed,
                    style: const TextStyle(fontSize: UIConfig.downloadPageGridViewSpeedTextSize, color: UIConfig.downloadPageGridTextColor),
                  ),
                )
              : Icon(
                  archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.needReUnlock.index
                      ? Icons.lock_open
                      : archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                          ? Icons.play_arrow
                          : archiveDownloadInfo.archiveStatus == ArchiveStatus.completed
                              ? Icons.done
                              : Icons.pause,
                  color: UIConfig.downloadPageGridTextColor,
                ),
        ),
      ),
    );
  }
}
