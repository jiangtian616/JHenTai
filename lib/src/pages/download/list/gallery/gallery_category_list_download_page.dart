import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';
import 'package:jhentai/src/widget/grouped_list.dart';

import '../../../../config/ui_config.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../setting/performance_setting.dart';
import '../../../../widget/eh_image.dart';
import '../../download_base_page.dart';
import 'gallery_category_list_download_page_logic.dart';
import 'gallery_category_list_download_page_state.dart';

class GalleryCategoryListDownloadPage extends StatelessWidget
    with
        Scroll2TopPageMixin,
        MultiSelectDownloadPageMixin,
        GalleryDownloadPageMixin {
  GalleryCategoryListDownloadPage({Key? key}) : super(key: key);

  final GalleryCategoryListDownloadPageLogic logic =
      Get.put<GalleryCategoryListDownloadPageLogic>(
          GalleryCategoryListDownloadPageLogic(),
          permanent: true);
  final GalleryCategoryListDownloadPageState state =
      Get.find<GalleryCategoryListDownloadPageLogic>().state;

  @override
  MultiSelectDownloadPageLogicMixin get multiSelectDownloadPageLogic => logic;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  GalleryDownloadPageLogicMixin get galleryDownloadPageLogic => logic;

  @override
  GalleryDownloadPageStateMixin get galleryDownloadPageState => state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(context),
      floatingActionButton: buildFloatingActionButton(),
      bottomNavigationBar: buildBottomAppBar(),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      titleSpacing: 0,
      title: const DownloadPageSegmentControl(
          galleryType: DownloadPageGalleryType.downloadCategory),
      actions: [
        PopupMenuButton(
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view),
                    const SizedBox(width: 12),
                    Text('switch2GridMode'.tr)
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.done_all),
                    const SizedBox(width: 12),
                    Text('multiSelect'.tr)
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow),
                    const SizedBox(width: 12),
                    Text('resumeAllTasks'.tr)
                  ],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pause),
                    const SizedBox(width: 12),
                    Text('pauseAllTasks'.tr)
                  ],
                ),
              ),
            ];
          },
          onSelected: (value) {
            if (value == 0) {
              DownloadPageBodyTypeChangeNotification(
                      bodyType: DownloadPageBodyType.grid)
                  .dispatch(context);
            }
            if (value == 1) {
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
      ],
      bottom: _buildAuthorFilterBar(context),
    );
  }

  PreferredSizeWidget _buildAuthorFilterBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: TextField(
            controller: logic.authorFilterController,
            onChanged: logic.updateAuthorFilterKeyword,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'filter'.tr,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    return GetBuilder<GalleryDownloadService>(
      id: logic.downloadService.galleryCountChangedId,
      builder: (_) => GetBuilder<GalleryCategoryListDownloadPageLogic>(
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: FutureBuilder(
            future: state.displayGroupsCompleter.future,
            builder: (_, __) => !state.displayGroupsCompleter.isCompleted
                ? const Center()
                : GroupedList<String, GalleryDownloadedData>(
                    maxGalleryNum4Animation:
                        performanceSetting.maxGalleryNum4Animation.value,
                    scrollController: state.scrollController,
                    controller: state.groupedListController,
                    groups: logic.getAuthorGroupOpenStates(),
                    elements: logic.downloadService.gallerys,
                    elementGroup: logic.downloadService.authorOfGallery,
                    groupBuilder: (context, groupName, isOpen) =>
                        _groupBuilder(context, groupName, isOpen).marginAll(5),
                    elementBuilder: (BuildContext context, String group,
                            GalleryDownloadedData gallery, isOpen) =>
                        _itemBuilder(context, gallery),
                    groupUniqueKey: (String group) => group,
                    elementUniqueKey: (GalleryDownloadedData gallery) =>
                        gallery.gid.toString(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _groupBuilder(BuildContext context, String groupName, bool isOpen) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      child: Container(
        height: UIConfig.groupListHeight,
        decoration: BoxDecoration(
          color: UIConfig.groupListColor(context),
          boxShadow: [if (!Get.isDarkMode) UIConfig.groupListShadow(context)],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: UIConfig.downloadPageGroupHeaderWidth,
                child: Center(child: Icon(Icons.folder_open))),
            Expanded(
              child: Text(
                '$groupName(${logic.downloadService.gallerysWithAuthor(groupName).length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GroupOpenIndicator(isOpen: isOpen).marginOnly(right: 8),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, GalleryDownloadedData gallery) {
    return Slidable(
      key: Key(gallery.gid.toString()),
      endActionPane: _buildEndActionPane(context, gallery),
      child: GestureDetector(
        onSecondaryTap: () =>
            logic.handleLongPressOrSecondaryTapItem(gallery, context),
        onLongPress: () =>
            logic.handleLongPressOrSecondaryTapItem(gallery, context),
        child: _buildGallery(context, gallery).marginAll(5),
      ),
    );
  }

  ActionPane _buildEndActionPane(
      BuildContext context, GalleryDownloadedData gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.15,
      children: [
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: UIConfig.alertColor(context),
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (BuildContext context) =>
              logic.handleRemoveItem(gallery, true, context),
        )
      ],
    );
  }

  Widget _buildGallery(BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<GalleryCategoryListDownloadPageLogic>(
      id: '${logic.itemCardId}::${gallery.gid}',
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.handleTapItem(gallery),
        child: Container(
          height: UIConfig.downloadPageCardHeight,
          decoration: state.selectedGids.contains(gallery.gid)
              ? BoxDecoration(
                  color: UIConfig.downloadPageCardSelectedColor(context),
                  borderRadius: BorderRadius.circular(
                      UIConfig.downloadPageCardBorderRadius),
                )
              : null,
          child: Row(
            children: [
              _buildCover(context, gallery),
              Expanded(child: _buildInfo(gallery)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
      builder: (_) {
        GalleryImage? image =
            logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

        if (image?.downloadStatus != DownloadStatus.downloaded) {
          return SizedBox(
            width: UIConfig.downloadPageCoverWidth,
            height: UIConfig.downloadPageCoverHeight,
            child: Center(child: UIConfig.loadingAnimation(context)),
          );
        }

        return EHImage(
          galleryImage: image!,
          containerWidth: UIConfig.downloadPageCoverWidth,
          containerHeight: UIConfig.downloadPageCoverHeight,
          borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
          fit: BoxFit.fitWidth,
          maxBytes: 2 * 1024 * 1024,
        );
      },
    );
  }

  Widget _buildInfo(GalleryDownloadedData gallery) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 6, right: 10, bottom: 6, top: 6),
          alignment: Alignment.centerLeft,
          child: Text(
            gallery.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: UIConfig.downloadPageCardTitleSize, height: 1.2),
          ),
        ),
        if (state.selectedGids.contains(gallery.gid))
          const Positioned(child: Center(child: Icon(Icons.check_circle))),
      ],
    );
  }
}
