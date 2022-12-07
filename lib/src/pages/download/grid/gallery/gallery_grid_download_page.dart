import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download/grid/gallery/gallery_grid_download_page_state.dart';

import '../../download_base_page.dart';
import '../base/grid_base_page.dart';
import 'gallery_grid_download_page_logic.dart';

class GalleryGridDownloadPage extends GridBasePage {
  GalleryGridDownloadPage({Key? key}) : super(key: key);

  @override
  DownloadPageGalleryType galleryType = DownloadPageGalleryType.download;
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
      images: gallerys.map((gallery) => logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0]).toList(),
      onTap: () => logic.enterGroup(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondTap: () => logic.handleLongPressGroup(groupName),
    );
  }

  @override
  Widget galleryBuilder(BuildContext context, List galleryObjects, int index) {
    return GridGallery(
      title: galleryObjects[index].title,
      cover: logic.downloadService.galleryDownloadInfos[galleryObjects[index].gid]?.images[0],
      onTapCover: () => logic.goToReadPage(galleryObjects[index]),
      onTapTitle: () => logic.goToDetailPage(index),
      onLongPress: () => logic.showBottomSheet(galleryObjects[index], context),
      onSecondTap: () => logic.showBottomSheet(galleryObjects[index], context),
    );
  }
}
