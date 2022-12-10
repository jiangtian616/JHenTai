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
  Widget groupBuilder(BuildContext context, int index) {
    String groupName = state.allRootGroups[index];
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
                    blurColor: Colors.black,
                    colorOpacity: 0.6,
                    child: cover,
                    overlay: const Icon(Icons.download, color: Colors.white),
                  ),
                );
              },
            ),
          )
          .toList(),
      onTap: () => logic.enterGroup(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondTap: () => logic.handleLongPressGroup(groupName),
    );
  }

  @override
  Widget galleryBuilder(BuildContext context, List galleryObjects, int index) {
    return GridGallery(
      title: galleryObjects[index].title,
      widget: GetBuilder<ArchiveDownloadService>(
        id: '${ArchiveDownloadService.archiveStatusId}::${galleryObjects[index].gid}',
        builder: (_) {
          Widget cover = buildGalleryImage(GalleryImage(url: galleryObjects[index].coverUrl));

          if (logic.archiveDownloadService.archiveDownloadInfos[galleryObjects[index].gid]?.archiveStatus == ArchiveStatus.completed) {
            return cover;
          }

          ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[galleryObjects[index].gid]!;

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Blur(blur: 1, blurColor: Colors.black, colorOpacity: 0.6, child: cover),
              ),
              Center(
                child: GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${galleryObjects[index].gid}::${galleryObjects[index].isOriginal}',
                  builder: (_) => ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: UIConfig.downloadPageGridViewCircularProgressSize,
                      minHeight: UIConfig.downloadPageGridViewCircularProgressSize,
                    ),
                    child: CircularProgressIndicator(
                      value: archiveDownloadInfo.speedComputer.downloadedBytes / galleryObjects[index].size,
                      color: Colors.white,
                      backgroundColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
              Center(
                child: GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${galleryObjects[index].gid}::${galleryObjects[index].isOriginal}',
                  builder: (_) => Text(
                    '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())} / ${byte2String(galleryObjects[index].size.toDouble())}',
                    style: const TextStyle(fontSize: UIConfig.downloadPageGridViewInfoTextSize, color: Colors.white),
                  ),
                ).marginOnly(top: 60),
              ),
              GestureDetector(
                onTap: () => archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                    ? logic.archiveDownloadService.resumeDownloadArchive(galleryObjects[index])
                    : logic.archiveDownloadService.pauseDownloadArchive(galleryObjects[index]),
                child: Center(
                  child: GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveStatusId}::${galleryObjects[index].gid}',
                    builder: (_) => archiveDownloadInfo.archiveStatus.index > ArchiveStatus.paused.index &&
                            archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index
                        ? GetBuilder<ArchiveDownloadService>(
                            id: '${ArchiveDownloadService.archiveSpeedComputerId}::${galleryObjects[index].gid}::${galleryObjects[index].isOriginal}',
                            builder: (_) => Text(
                              archiveDownloadInfo.speedComputer.speed,
                              style: const TextStyle(fontSize: UIConfig.downloadPageGridViewSpeedTextSize, color: Colors.white),
                            ),
                          )
                        : Icon(
                            archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                                ? Icons.play_arrow
                                : archiveDownloadInfo.archiveStatus == ArchiveStatus.completed
                                    ? Icons.done
                                    : Icons.pause,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      onTapWidget: () => logic.goToReadPage(galleryObjects[index]),
      onTapTitle: () => logic.goToDetailPage(index),
      onLongPress: () => logic.showArchiveBottomSheet(galleryObjects[index], context),
      onSecondTap: () => logic.showArchiveBottomSheet(galleryObjects[index], context),
      onTertiaryTap: () => logic.goToDetailPage(index),
    );
  }
}
