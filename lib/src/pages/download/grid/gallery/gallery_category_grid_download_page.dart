import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../config/ui_config.dart';
import '../../../../model/gallery_image.dart';
import '../../../../service/gallery_download_service.dart';
import '../../download_base_page.dart';
import '../mixin/grid_download_page_mixin.dart';
import 'gallery_category_grid_download_page_logic.dart';
import 'gallery_category_grid_download_page_state.dart';

class GalleryCategoryGridDownloadPage extends StatelessWidget
    with
        Scroll2TopPageMixin,
        MultiSelectDownloadPageMixin,
        GalleryDownloadPageMixin,
        GridBasePage {
  GalleryCategoryGridDownloadPage({Key? key}) : super(key: key);

  @override
  final DownloadPageGalleryType galleryType =
      DownloadPageGalleryType.downloadCategory;
  @override
  final GalleryCategoryGridDownloadPageLogic logic =
      Get.put<GalleryCategoryGridDownloadPageLogic>(
          GalleryCategoryGridDownloadPageLogic(),
          permanent: true);
  @override
  final GalleryCategoryGridDownloadPageState state =
      Get.find<GalleryCategoryGridDownloadPageLogic>().state;

  @override
  GalleryDownloadPageLogicMixin get galleryDownloadPageLogic => logic;

  @override
  GalleryDownloadPageStateMixin get galleryDownloadPageState => state;

  @override
  MultiSelectDownloadPageLogicMixin get multiSelectDownloadPageLogic => logic;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return [
      PopupMenuButton(
        itemBuilder: (context) {
          return [
            PopupMenuItem(
              value: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_list),
                  const SizedBox(width: 12),
                  Text('switch2ListMode'.tr)
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
                    bodyType: DownloadPageBodyType.list)
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
    ];
  }

  @override
  PreferredSizeWidget? buildAppBarBottom(BuildContext context) {
    return _buildAuthorFilterBar(context);
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget? buildGridBottomAppBar(BuildContext context) {
    return buildBottomAppBar();
  }

  @override
  GridGroup groupBuilder(
      BuildContext context, String groupName, bool inEditMode) {
    List<GalleryDownloadedData> gallerys =
        state.galleryObjectsWithGroup(groupName);
    return GridGroup(
      groupName: groupName,
      contentSize: gallerys.length,
      widgets: gallerys
          .sublist(0, min(GridGroup.maxWidgetCount, gallerys.length))
          .map((gallery) => _buildGroupCover(context, gallery))
          .toList(),
      onTap: () => logic.enterGroup(groupName),
    );
  }

  @override
  GridGallery galleryBuilder(
      BuildContext context, GalleryDownloadedData gallery, bool inEditMode) {
    return GridGallery(
      title: gallery.title,
      widget: GetBuilder<GalleryCategoryGridDownloadPageLogic>(
        id: '${logic.itemCardId}::${gallery.gid}',
        builder: (_) => Stack(
          children: [
            _buildCover(context, gallery),
            if (state.selectedGids.contains(gallery.gid)) _buildSelectedIcon(),
          ],
        ),
      ),
      parseFromBot: false,
      isOriginal: gallery.downloadOriginalImage,
      readProgressRecordKey: gallery.gid.toString(),
      pageCount: gallery.pageCount,
      gid: gallery.gid,
      superResolutionType: SuperResolutionType.gallery,
      onTapWidget: () => logic.handleTapItem(gallery),
      onTapTitle: () => logic.handleTapItem(gallery),
      onLongPress: () =>
          logic.handleLongPressOrSecondaryTapItem(gallery, context),
      onSecondTap: () =>
          logic.handleLongPressOrSecondaryTapItem(gallery, context),
      onTertiaryTap: () => logic.handleTapItem(gallery),
    );
  }

  GetBuilder<GalleryDownloadService> _buildGroupCover(
      BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
      builder: (_) {
        GalleryImage? image =
            logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

        if (image?.downloadStatus == DownloadStatus.downloaded) {
          return buildGroupInnerImage(image!);
        }

        return Center(
          child: LoadingAnimationWidget.horizontalRotatingDots(
              color: UIConfig.downloadPageLoadingIndicatorColor(context),
              size: 16),
        );
      },
    );
  }

  GetBuilder<GalleryDownloadService> _buildCover(
      BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
      builder: (_) {
        GalleryImage? image =
            logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

        if (image?.downloadStatus == DownloadStatus.downloaded) {
          return buildGalleryImage(image!);
        }

        return Center(
          child: LoadingAnimationWidget.horizontalRotatingDots(
              color: UIConfig.downloadPageLoadingIndicatorColor(context),
              size: 16),
        );
      },
    );
  }

  Widget _buildSelectedIcon() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: UIConfig.downloadPageGridViewSelectIconColor),
          color: UIConfig.downloadPageGridViewSelectIconBackGroundColor,
        ),
        child: const Icon(Icons.check,
            color: UIConfig.downloadPageGridViewSelectIconColor),
      ),
    );
  }
}
