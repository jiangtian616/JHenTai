import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:path/path.dart';

import '../../../../setting/style_setting.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../base/grid_base_page.dart';
import 'local_gallery_grid_page_logic.dart';
import 'local_gallery_grid_page_state.dart';

class LocalGalleryGridPage extends GridBasePage {
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
      leading: StyleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: DownloadPageSegmentControl(galleryType: galleryType),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 26),
          onPressed: logic.handleRefreshLocalGallery,
        ),
        IconButton(
          icon: const Icon(Icons.grid_view),
          onPressed: () => DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.list).dispatch(context),
        ),
      ],
    );
  }

  @override
  int itemCount() {
    return logic.computeItemCount();
  }

  @override
  Widget itemBuilder(context, index) {
    if (state.isAtRoot) {
      return groupBuilder(context, index);
    }

    if (index == 0) {
      return ReturnWidget(onTap: logic.backRoute);
    }

    index--;

    if (index < logic.computeCurrentDirectoryCount()) {
      return groupBuilder(context, index);
    }

    return galleryBuilder(context, state.currentGalleryObjects, index - logic.computeCurrentDirectoryCount());
  }

  @override
  Widget groupBuilder(BuildContext context, int index) {
    String groupName = logic.computeChildPath(index);

    return GridGroup(
      groupName: logic.transformDisplayPath(logic.isAtRootPath ? groupName : relative(groupName, from: state.currentGroup)),
      widgets: [],
      emptyIcon: state.isAtRoot ? Icons.folder_special : null,
      onTap: () => logic.enterGroup(groupName),
    );
  }

  @override
  Widget galleryBuilder(BuildContext context, List galleryObjects, int index) {
    return GridGallery(
      title: galleryObjects[index].title,
      widget: buildGalleryImage(galleryObjects[index].cover),
      onTapWidget: () => logic.goToReadPage(galleryObjects[index]),
      onTapTitle:
          galleryObjects[index].isFromEHViewer ? () => logic.goToDetailPage(galleryObjects[index]) : () => logic.goToReadPage(galleryObjects[index]),
      onLongPress: () => logic.showBottomSheet(galleryObjects[index], context),
      onSecondTap: () => logic.showBottomSheet(galleryObjects[index], context),
      onTertiaryTap: galleryObjects[index].isFromEHViewer ? () => logic.goToDetailPage(galleryObjects[index]) : () => logic.goToReadPage(galleryObjects[index]),
    );
  }
}
