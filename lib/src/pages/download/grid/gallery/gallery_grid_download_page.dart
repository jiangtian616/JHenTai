import 'dart:math';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download/grid/gallery/gallery_grid_download_page_state.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../config/ui_config.dart';
import '../../../../model/gallery_image.dart';
import '../../../../service/gallery_download_service.dart';
import '../../download_base_page.dart';
import '../base/grid_base_page.dart';
import 'gallery_grid_download_page_logic.dart';

class GalleryGridDownloadPage extends GridBasePage {
  GalleryGridDownloadPage({Key? key}) : super(key: key);

  @override
  final DownloadPageGalleryType galleryType = DownloadPageGalleryType.download;
  @override
  final GalleryGridDownloadPageLogic logic = Get.put<GalleryGridDownloadPageLogic>(GalleryGridDownloadPageLogic(), permanent: true);
  @override
  final GalleryGridDownloadPageState state = Get.find<GalleryGridDownloadPageLogic>().state;

  @override
  GridGroup groupBuilder(BuildContext context, String groupName, bool inEditMode) {
    List<GalleryDownloadedData> gallerys = state.galleryObjectsWithGroup(groupName);
    return GridGroup(
      groupName: groupName,
      widgets: gallerys
          .sublist(0, min(GridGroup.maxWidgetCount, gallerys.length))
          .map(
            (gallery) => GetBuilder<GalleryDownloadService>(
              id: '${logic.downloadService.galleryDownloadSuccessId}::${gallery.gid}',
              builder: (_) => GetBuilder<GalleryDownloadService>(
                id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
                builder: (_) {
                  GalleryImage? image = logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

                  if (image == null) {
                    return Center(
                      child: LoadingAnimationWidget.horizontalRotatingDots(color: UIConfig.downloadPageLoadingIndicatorColor, size: 16),
                    );
                  }

                  Widget cover = buildGroupInnerImage(image);

                  if (logic.downloadService.galleryDownloadInfos[gallery.gid]?.downloadProgress.downloadStatus == DownloadStatus.downloaded) {
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
            ),
          )
          .toList(),
      onTap: inEditMode ? null : () => logic.enterGroup(groupName),
      onLongPress: inEditMode ? null : () => logic.handleLongPressGroup(groupName),
      onSecondTap: inEditMode ? null : () => logic.handleLongPressGroup(groupName),
    );
  }

  @override
  GridGallery galleryBuilder(BuildContext context, GalleryDownloadedData gallery, bool inEditMode) {
    return GridGallery(
      title: gallery.title,
      widget: GetBuilder<GalleryDownloadService>(
        id: '${logic.downloadService.galleryDownloadSuccessId}::${gallery.gid}',
        builder: (_) {
          Widget cover = GetBuilder<GalleryDownloadService>(
            id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
            builder: (_) {
              GalleryImage? image = logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

              if (image?.downloadStatus != DownloadStatus.downloaded) {
                return const Center();
              }

              return buildGalleryImage(image!);
            },
          );

          if (logic.downloadService.galleryDownloadInfos[gallery.gid]?.downloadProgress.downloadStatus == DownloadStatus.downloaded) {
            return cover;
          }

          GalleryDownloadProgress downloadProgress = logic.downloadService.galleryDownloadInfos[gallery.gid]!.downloadProgress;
          GalleryDownloadSpeedComputer speedComputer = logic.downloadService.galleryDownloadInfos[gallery.gid]!.speedComputer;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Blur(blur: 1, blurColor: UIConfig.downloadPageGridCoverBlurColor, colorOpacity: 0.6, child: cover),
              ),
              Center(
                child: GetBuilder<GalleryDownloadService>(
                  id: '${logic.downloadService.galleryDownloadProgressId}::${gallery.gid}',
                  builder: (_) => ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: UIConfig.downloadPageGridViewCircularProgressSize,
                      minHeight: UIConfig.downloadPageGridViewCircularProgressSize,
                    ),
                    child: CircularProgressIndicator(
                      value: downloadProgress.curCount / downloadProgress.totalCount,
                      color: UIConfig.downloadPageGridProgressColor,
                      backgroundColor: UIConfig.downloadPageGridProgressBackGroundColor,
                    ),
                  ),
                ),
              ),
              Center(
                child: GetBuilder<GalleryDownloadService>(
                  id: '${logic.downloadService.galleryDownloadProgressId}::${gallery.gid}',
                  builder: (_) => Text(
                    '${downloadProgress.curCount} / ${downloadProgress.totalCount}',
                    style: const TextStyle(fontSize: UIConfig.downloadPageGridViewInfoTextSize, color: UIConfig.downloadPageGridTextColor),
                  ),
                ).marginOnly(top: 60),
              ),
              GestureDetector(
                onTap: () {
                  downloadProgress.downloadStatus == DownloadStatus.paused
                      ? logic.downloadService.resumeDownloadGallery(gallery)
                      : logic.downloadService.pauseDownloadGallery(gallery);
                },
                child: Center(
                  child: GetBuilder<GalleryDownloadService>(
                    id: '${logic.downloadService.galleryDownloadProgressId}::${gallery.gid}',
                    builder: (_) => downloadProgress.downloadStatus == DownloadStatus.downloading
                        ? GetBuilder<GalleryDownloadService>(
                            id: '${logic.downloadService.galleryDownloadSpeedComputerId}::${gallery.gid}',
                            builder: (_) => Text(
                              speedComputer.speed,
                              style: const TextStyle(fontSize: UIConfig.downloadPageGridViewSpeedTextSize, color: UIConfig.downloadPageGridTextColor),
                            ),
                          )
                        : Icon(
                            downloadProgress.downloadStatus == DownloadStatus.paused ? Icons.play_arrow : Icons.done,
                            color: UIConfig.downloadPageGridTextColor,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      onTapWidget: inEditMode ? null : () => logic.goToReadPage(gallery),
      onTapTitle: inEditMode ? null : () => logic.goToDetailPage(gallery),
      onLongPress: inEditMode ? null : () => logic.showBottomSheet(gallery, context),
      onSecondTap: inEditMode ? null : () => logic.showBottomSheet(gallery, context),
      onTertiaryTap: inEditMode ? null : () => logic.goToDetailPage(gallery),
    );
  }
}
