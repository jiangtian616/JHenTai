import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:path/path.dart' as p;

import '../../../config/ui_config.dart';
import '../../../utils/route_util.dart';
import '../../../utils/toast_util.dart';
import '../../../widget/eh_image.dart';
import '../../../widget/eh_wheel_speed_controller.dart';
import '../../../widget/fade_shrink_widget.dart';
import '../../../widget/focus_widget.dart';
import '../../layout/desktop/desktop_layout_page_logic.dart';
import '../download_base_page.dart';
import 'local_gallery_page_logic.dart';
import 'local_gallery_page_state.dart';

class LocalGalleryPage extends StatelessWidget {
  LocalGalleryPage({Key? key}) : super(key: key);

  final LocalGalleryPageLogic logic = Get.put<LocalGalleryPageLogic>(LocalGalleryPageLogic(), permanent: true);
  final LocalGalleryPageState state = Get.find<LocalGalleryPageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_upward),
        heroTag: null,
        onPressed: logic.scroll2Top,
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      titleSpacing: 0,
      title: const EHDownloadPageSegmentControl(bodyType: DownloadPageBodyType.local),
      leading: ExcludeFocus(
        child: IconButton(icon: const Icon(Icons.help), onPressed: () => toast('localGalleryHelpInfo'.tr, isShort: false)),
      ),
      actions: [
        ExcludeFocus(
          child: GetBuilder<LocalGalleryPageLogic>(
            id: LocalGalleryPageLogic.appBarId,
            builder: (_) => IconButton(
              icon: Icon(
                Icons.merge,
                size: 26,
                color: state.aggregateDirectories ? Get.theme.colorScheme.primary : Get.theme.colorScheme.outline,
              ),
              onPressed: logic.toggleAggregateDirectory,
              visualDensity: const VisualDensity(horizontal: -4),
            ),
          ),
        ),
        ExcludeFocus(
          child: IconButton(
            icon: Icon(Icons.refresh, size: 26, color: Get.theme.colorScheme.primary),
            onPressed: logic.handleRefreshLocalGallery,
          ),
        ),
      ],
    );
  }

  Widget buildBody() {
    return GetBuilder<LocalGalleryService>(
      id: LocalGalleryService.galleryCountChangedId,
      builder: (_) => GetBuilder<LocalGalleryPageLogic>(
        id: LocalGalleryPageLogic.bodyId,
        builder: (_) => EHWheelSpeedController(
          controller: state.scrollController,
          child: ListView.builder(
            controller: state.scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: logic.computeItemCount(),
            itemBuilder: (context, index) {
              if (state.aggregateDirectories) {
                return galleryItemBuilder(context, index);
              }

              if (index == 0) {
                return parentDirectoryItemBuilder(context);
              }

              if (index <= logic.computeCurrentDirectoryCount()) {
                return nestedDirectoryItemBuilder(context, index - 1);
              }

              return galleryItemBuilder(context, index - 1 - logic.computeCurrentDirectoryCount());
            },
          ),
        ),
      ),
    );
  }

  Widget parentDirectoryItemBuilder(BuildContext context) {
    return FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Get.theme.colorScheme.onBackground))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: logic.backRoute,
      handleTapArrowRight: logic.backRoute,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: logic.backRoute,
        child: _buildNestedDirectory('/..', context).marginAll(5),
      ),
    );
  }

  Widget nestedDirectoryItemBuilder(BuildContext context, int index) {
    String childPath = logic.computeChildPath(index);

    return FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Get.theme.colorScheme.onBackground))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => logic.pushRoute(childPath),
      handleTapArrowRight: () => logic.pushRoute(childPath),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.pushRoute(childPath),
        child: _buildNestedDirectory(p.relative(childPath, from: state.currentPath), context).marginAll(5),
      ),
    );
  }

  Widget _buildNestedDirectory(String displayPath, BuildContext context) {
    return Container(
      height: UIConfig.downloadPageGroupHeight,
      decoration: BoxDecoration(
        color: UIConfig.downloadPageGroupColor,
        boxShadow: [UIConfig.downloadPageGroupShadow],
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            const SizedBox(width: UIConfig.downloadPageGroupHeaderWidth, child: Center(child: Icon(Icons.folder_open))),
            Expanded(child: Text(displayPath, maxLines: 1, overflow: TextOverflow.ellipsis))
          ],
        ),
      ),
    );
  }

  Widget galleryItemBuilder(BuildContext context, int index) {
    LocalGallery gallery = state.aggregateDirectories
        ? logic.localGalleryService.allGallerys[index]
        : logic.localGalleryService.path2Gallerys[state.currentPath]![index];

    return FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Get.theme.colorScheme.onBackground))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => logic.goToReadPage(gallery),
      handleTapArrowRight: () => logic.goToReadPage(gallery),
      child: Slidable(
        key: Key(gallery.title),
        endActionPane: _buildEndActionPane(gallery),
        child: GestureDetector(
          onSecondaryTap: () => showBottomSheet(gallery, context),
          onLongPress: () => showBottomSheet(gallery, context),
          child: FadeShrinkWidget(
            show: !state.removedGalleryTitles.contains(gallery.title),
            child: _buildGallery(gallery, context).marginAll(5),
            afterDisappear: () {
              Get.engine.addPostFrameCallback(
                (_) => logic.localGalleryService.deleteGallery(gallery, state.currentPath),
              );
              state.removedGalleryTitles.remove(gallery.title);
            },
          ),
        ),
      ),
    );
  }

  ActionPane _buildEndActionPane(LocalGallery gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.15,
      children: [
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => logic.handleRemoveItem(gallery),
        )
      ],
    );
  }

  Widget _buildGallery(LocalGallery gallery, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => logic.goToReadPage(gallery),
      child: Container(
        height: UIConfig.downloadPageCardHeight,
        decoration: BoxDecoration(
          color: UIConfig.downloadPageCardColor,
          boxShadow: [UIConfig.downloadPageCardShadow],
          borderRadius: BorderRadius.circular(15),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Row(
            children: [
              _buildCover(gallery, context),
              Expanded(child: _buildInfo(gallery)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(LocalGallery gallery, BuildContext context) {
    return EHImage.file(
      containerWidth: UIConfig.downloadPageCoverWidth,
      containerHeight: UIConfig.downloadPageCoverHeight,
      fit: BoxFit.fitWidth,
      galleryImage: gallery.images[0],
    );
  }

  Widget _buildInfo(LocalGallery gallery) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gallery.title,
            maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: UIConfig.downloadPageCardTitleSize, height: 1.2)),
        const Expanded(child: SizedBox()),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              DateFormat('yyyy-MM-dd HH:mm:ss').format(gallery.time),
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${gallery.pageCount} P',
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
            ),
          ],
        ),
      ],
    ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5);
  }

  void showBottomSheet(LocalGallery gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              logic.handleRemoveItem(gallery);
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
}
