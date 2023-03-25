import 'dart:math';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';

import '../../../../model/gallery_image.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../utils/byte_util.dart';
import '../base/grid_base_page.dart';
import 'archive_grid_download_page_logic.dart';
import 'archive_grid_download_page_state.dart';

class ArchiveGridDownloadPage extends GridBasePage {
  ArchiveGridDownloadPage({Key? key}) : super(key: key);

  @override
  final DownloadPageGalleryType galleryType = DownloadPageGalleryType.archive;
  @override
  final ArchiveGridDownloadPageLogic logic = Get.put<ArchiveGridDownloadPageLogic>(ArchiveGridDownloadPageLogic(), permanent: true);
  @override
  final ArchiveGridDownloadPageState state = Get.find<ArchiveGridDownloadPageLogic>().state;

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
      widget: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
        builder: (_) {
          Widget cover = buildGalleryImage(GalleryImage(url: archive.coverUrl));

          if (logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus == ArchiveStatus.completed) {
            return cover;
          }

          ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Blur(blur: 1, blurColor: UIConfig.downloadPageGridCoverBlurColor, colorOpacity: 0.6, child: cover),
              ),
              Center(
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
              ),
              Center(
                child: GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                  builder: (_) => Text(
                    '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())} / ${byte2String(archive.size.toDouble())}',
                    style: const TextStyle(fontSize: UIConfig.downloadPageGridViewInfoTextSize, color: UIConfig.downloadPageGridTextColor),
                  ),
                ).marginOnly(top: 60),
              ),
              GestureDetector(
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
              ),
            ],
          );
        },
      ),
      onTapWidget: inEditMode ? null : () => logic.goToReadPage(archive),
      onTapTitle: inEditMode ? null : () => logic.goToDetailPage(archive),
      onLongPress: inEditMode ? null : () => logic.showArchiveBottomSheet(archive, context),
      onSecondTap: inEditMode ? null : () => logic.showArchiveBottomSheet(archive, context),
      onTertiaryTap: inEditMode ? null : () => logic.goToDetailPage(archive),
    );
  }
}
