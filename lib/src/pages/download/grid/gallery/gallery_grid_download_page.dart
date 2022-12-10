import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download/grid/gallery/gallery_grid_download_page_state.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
  Widget groupBuilder(BuildContext context, int index) {
    String groupName = state.allRootGroups[index];
    List<GalleryDownloadedData> gallerys = state.galleryObjectsWithGroup(groupName);
    return GridGroup(
      groupName: groupName,
      images: gallerys
          .map(
            (gallery) => GetBuilder<GalleryDownloadService>(
              id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
              builder: (_) {
                GalleryImage? image = logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

                if (image?.downloadStatus != DownloadStatus.downloaded) {
                  return Center(
                    child: LoadingAnimationWidget.horizontalRotatingDots(
                      color: Get.isDarkMode ? Colors.grey.shade200 : Colors.grey.shade800,
                      size: 16,
                    ),
                  );
                }

                return buildGroupInnerImage(image!);
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
      cover: GetBuilder<GalleryDownloadService>(
        id: '${logic.downloadService.downloadImageUrlId}::${galleryObjects[index].gid}::0',
        builder: (_) {
          GalleryImage? image = logic.downloadService.galleryDownloadInfos[galleryObjects[index].gid]?.images[0];

          if (image?.downloadStatus != DownloadStatus.downloaded) {
            return Center(child: UIConfig.loadingAnimation);
          }

          return buildGalleryImage(image!);
        },
      ),
      onTapCover: () => logic.goToReadPage(galleryObjects[index]),
      onTapTitle: () => logic.goToDetailPage(index),
      onLongPress: () => logic.showBottomSheet(galleryObjects[index], context),
      onSecondTap: () => logic.showBottomSheet(galleryObjects[index], context),
    );
  }
}
