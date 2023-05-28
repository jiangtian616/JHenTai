import 'package:flutter/material.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:path/path.dart';

import '../../../../utils/toast_util.dart';
import '../mixin/grid_download_page_mixin.dart';
import 'local_gallery_grid_page_logic.dart';
import 'local_gallery_grid_page_state.dart';

class LocalGalleryGridPage extends StatelessWidget with Scroll2TopPageMixin, GridBasePage {
  LocalGalleryGridPage({Key? key}) : super(key: key);

  @override
  final DownloadPageGalleryType galleryType = DownloadPageGalleryType.local;
  @override
  final LocalGalleryGridPageLogic logic = Get.put<LocalGalleryGridPageLogic>(LocalGalleryGridPageLogic(), permanent: true);
  @override
  final LocalGalleryGridPageState state = Get.find<LocalGalleryGridPageLogic>().state;

  @override
  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.help),
        onPressed: () =>
            toast((GetPlatform.isIOS || GetPlatform.isMacOS) ? 'localGalleryHelpInfo4iOSAndMacOS'.tr : 'localGalleryHelpInfo'.tr, isShort: false),
      ),
      titleSpacing: 0,
      title: DownloadPageSegmentControl(galleryType: galleryType),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 26),
          onPressed: logic.handleRefreshLocalGallery,
        ),
        IconButton(
          icon: const Icon(Icons.view_list),
          onPressed: () => DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.list).dispatch(context),
        ),
      ],
    );
  }

  @override
  List<DraggableGridItem> getChildren(BuildContext context) {
    return logic.isAtRootPath
        ? logic.localGalleryService.rootDirectories.map((dir) => DraggableGridItem(child: groupBuilder(context, dir, false))).toList()
        : [
            DraggableGridItem(child: ReturnWidget(onTap: logic.backRoute)),
            ...?logic.localGalleryService.path2SubDir[logic.currentPath]
                ?.map((subDir) => DraggableGridItem(child: groupBuilder(context, subDir, false))),
            ...state.currentGalleryObjects.map((gallery) => DraggableGridItem(child: galleryBuilder(context, gallery, false))),
          ];
  }

  @override
  GridGroup groupBuilder(BuildContext context, String groupName, bool inEditMode) {
    return GridGroup(
      groupName: logic.transformDisplayPath(logic.isAtRootPath ? groupName : relative(groupName, from: state.currentGroup)),
      widgets: const [],
      emptyIcon: state.isAtRoot ? Icons.folder_special : null,
      onTap: () => logic.enterGroup(groupName),
    );
  }

  @override
  GridGallery galleryBuilder(BuildContext context, LocalGallery gallery, bool inEditMode) {
    return GridGallery(
      title: gallery.title,
      widget: buildGalleryImage(gallery.cover),
      isOriginal: false,
      onTapWidget: () => logic.goToReadPage(gallery),
      onTapTitle: gallery.isFromEHViewer ? () => logic.goToDetailPage(gallery) : () => logic.goToReadPage(gallery),
      onLongPress: () => logic.showBottomSheet(gallery, context),
      onSecondTap: () => logic.showBottomSheet(gallery, context),
      onTertiaryTap: gallery.isFromEHViewer ? () => logic.goToDetailPage(gallery) : () => logic.goToReadPage(gallery),
    );
  }
}
