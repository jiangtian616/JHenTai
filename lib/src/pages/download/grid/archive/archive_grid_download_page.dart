import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';

import '../../../../model/gallery_image.dart';
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
      images: archives.map((archive) => buildGroupInnerImage(GalleryImage(url: archive.coverUrl))).toList(),
      onTap: () => logic.enterGroup(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondTap: () => logic.handleLongPressGroup(groupName),
    );
  }

  @override
  Widget galleryBuilder(BuildContext context, List galleryObjects, int index) {
    return GridGallery(
      title: galleryObjects[index].title,
      cover: buildGalleryImage(GalleryImage(url: galleryObjects[index].coverUrl)),
      onTapCover: () => logic.goToReadPage(galleryObjects[index]),
      onTapTitle: () => logic.goToDetailPage(index),
      onLongPress: () => logic.showArchiveBottomSheet(galleryObjects[index], context),
      onSecondTap: () => logic.showArchiveBottomSheet(galleryObjects[index], context),
    );
  }
}
