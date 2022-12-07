import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../utils/date_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_gallery_category_tag.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/fade_shrink_widget.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../../download_base_page.dart';
import 'gallery_list_download_page_logic.dart';
import 'gallery_list_download_page_state.dart';

class GalleryListDownloadPage extends StatelessWidget with Scroll2TopPageMixin {
  GalleryListDownloadPage({Key? key}) : super(key: key);

  @override
  final GalleryListDownloadPageLogic logic = Get.put<GalleryListDownloadPageLogic>(GalleryListDownloadPageLogic(), permanent: true);
  @override
  final GalleryListDownloadPageState state = Get.find<GalleryListDownloadPageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: StyleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: const DownloadPageSegmentControl(galleryType: DownloadPageGalleryType.download),
      actions: [
        IconButton(
          icon: const Icon(Icons.view_list),
          onPressed: () => DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.grid).dispatch(context),
        ),
      ],
    );
  }

  Widget buildBody() {
    return GetBuilder<GalleryDownloadService>(
      id: logic.downloadService.galleryCountOrOrderChangedId,
      builder: (_) => GetBuilder<GalleryListDownloadPageLogic>(
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: GroupList<GalleryDownloadedData, String>(
            scrollController: state.scrollController,
            groups: logic.downloadService.allGroups,
            elements: logic.downloadService.gallerys,
            groupBy: (GalleryDownloadedData gallery) => logic.downloadService.galleryDownloadInfos[gallery.gid]?.group ?? 'default'.tr,
            groupBuilder: (context, groupName) => _groupBuilder(context, groupName).marginAll(5),
            itemBuilder: (BuildContext context, GalleryDownloadedData gallery) => _itemBuilder(gallery, context),
          ),
        ),
      ),
    );
  }

  Widget _groupBuilder(BuildContext context, String groupName) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondaryTap: () => logic.handleLongPressGroup(groupName),
      child: Container(
        height: UIConfig.downloadPageGroupHeight,
        decoration: BoxDecoration(
          color: UIConfig.downloadPageGroupColor(context),
          boxShadow: [UIConfig.downloadPageGroupShadow],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SizedBox(width: UIConfig.downloadPageGroupHeaderWidth, child: Center(child: Icon(Icons.folder_open))),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GetBuilder<GalleryListDownloadPageLogic>(
              id: '${logic.groupId}::$groupName',
              builder: (_) => GroupOpenIndicator(isOpen: state.displayGroups.contains(groupName)).marginOnly(right: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(GalleryDownloadedData gallery, BuildContext context) {
    String? group = logic.downloadService.galleryDownloadInfos[gallery.gid]?.group;

    return GetBuilder<GalleryListDownloadPageLogic>(
      id: '${logic.groupId}::$group',
      builder: (_) => Slidable(
        key: Key(gallery.gid.toString()),
        endActionPane: _buildEndActionPane(gallery),
        child: GestureDetector(
          onSecondaryTap: () => logic.showBottomSheet(gallery, context),
          onLongPress: () => logic.showBottomSheet(gallery, context),
          child: FadeShrinkWidget(
            show: state.displayGroups.contains(group),
            child: FadeShrinkWidget(
              show: !state.removedGids.contains(gallery.gid) && !state.removedGidsWithoutImages.contains(gallery.gid),
              child: _buildCard(gallery, context).marginAll(5),
              afterDisappear: () {
                Get.engine.addPostFrameCallback(
                  (_) {
                    logic.downloadService.deleteGallery(gallery, deleteImages: state.removedGids.contains(gallery.gid));
                    state.removedGids.remove(gallery.gid);
                    state.removedGidsWithoutImages.remove(gallery.gid);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  ActionPane _buildEndActionPane(GalleryDownloadedData gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.4,
      children: [
        SlidableAction(
          icon: Icons.bookmark,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (_) => logic.handleChangeGroup(gallery),
        ),
        SlidableAction(
          icon: FontAwesomeIcons.sort,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => logic.showPrioritySheet(gallery, context),
        ),
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => logic.handleRemoveItem(gallery, true),
        )
      ],
    );
  }

  Widget _buildCard(GalleryDownloadedData gallery, BuildContext context) {
    return Container(
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
            _buildInfo(gallery),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(GalleryDownloadedData gallery, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(Routes.details, arguments: {'galleryUrl': gallery.galleryUrl}),
      child: GetBuilder<GalleryDownloadService>(
        id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
        builder: (_) {
          GalleryImage? image = logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

          /// cover is the first image, if we haven't downloaded first image, then return a [UIConfig.loadingAnimation]
          if (image?.downloadStatus != DownloadStatus.downloaded) {
            return SizedBox(
              width: UIConfig.downloadPageCoverWidth,
              height: UIConfig.downloadPageCoverHeight,
              child: Center(child: UIConfig.loadingAnimation),
            );
          }

          return EHImage(
            galleryImage: image!,
            containerWidth: UIConfig.downloadPageCoverWidth,
            containerHeight: UIConfig.downloadPageCoverHeight,
            fit: BoxFit.fitWidth,
          );
        },
      ),
    );
  }

  Widget _buildInfo(GalleryDownloadedData gallery) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.goToReadPage(gallery),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoHeader(gallery),
            const Expanded(child: SizedBox()),
            _buildInfoCenter(gallery),
            const Expanded(child: SizedBox()),
            _buildInfoFooter(gallery),
          ],
        ).paddingOnly(left: 6, right: 10, bottom: 6, top: 6),
      ),
    );
  }

  Widget _buildInfoHeader(GalleryDownloadedData gallery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gallery.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: UIConfig.downloadPageCardTitleSize, height: 1.2),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (gallery.uploader != null)
              Text(
                gallery.uploader!,
                style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
              ),
            Text(
              DateUtil.transform2LocalTimeString(gallery.publishTime),
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
            ),
          ],
        ).marginOnly(top: 5),
      ],
    );
  }

  Widget _buildInfoCenter(GalleryDownloadedData gallery) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGalleryCategoryTag(category: gallery.category),
        const Expanded(child: SizedBox()),
        _buildIsOriginal(gallery).marginOnly(right: 10),
        _buildPriority(gallery).marginOnly(right: 6),
        _buildButton(gallery),
      ],
    );
  }

  Widget _buildIsOriginal(GalleryDownloadedData gallery) {
    bool isOriginal = gallery.downloadOriginalImage;
    if (!isOriginal) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: UIConfig.pauseButtonColor),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(color: UIConfig.pauseButtonColor, fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildPriority(GalleryDownloadedData gallery) {
    int? priority = logic.downloadService.galleryDownloadInfos[gallery.gid]?.priority;
    if (priority == null) {
      return const SizedBox();
    }

    switch (priority) {
      case 1:
        return Text('①', style: TextStyle(color: UIConfig.pauseButtonColor, fontWeight: FontWeight.bold));
      case 2:
        return Text('②', style: TextStyle(color: UIConfig.pauseButtonColor, fontWeight: FontWeight.bold));
      case 3:
        return Text('③', style: TextStyle(color: UIConfig.pauseButtonColor, fontWeight: FontWeight.bold));
      case GalleryDownloadService.defaultDownloadGalleryPriority:
        return const SizedBox();
      case 5:
        return Text('⑤', style: TextStyle(color: UIConfig.pauseButtonColor, fontWeight: FontWeight.bold));
      default:
        return const SizedBox();
    }
  }

  Widget _buildButton(GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.downloadService.galleryDownloadProgressId}::${gallery.gid}',
      builder: (_) {
        DownloadStatus downloadStatus = logic.downloadService.galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus;
        return GestureDetector(
          onTap: () {
            downloadStatus == DownloadStatus.paused
                ? logic.downloadService.resumeDownloadGallery(gallery)
                : logic.downloadService.pauseDownloadGallery(gallery);
          },
          child: Icon(
            downloadStatus == DownloadStatus.paused
                ? Icons.play_arrow
                : downloadStatus == DownloadStatus.downloading
                    ? Icons.pause
                    : Icons.done,
            size: 26,
            color: downloadStatus == DownloadStatus.downloading ? UIConfig.pauseButtonColor : UIConfig.resumeButtonColor,
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '${logic.downloadService.galleryDownloadProgressId}::${gallery.gid}',
      builder: (_) {
        GalleryDownloadProgress downloadProgress = logic.downloadService.galleryDownloadInfos[gallery.gid]!.downloadProgress;
        GalleryDownloadSpeedComputer speedComputer = logic.downloadService.galleryDownloadInfos[gallery.gid]!.speedComputer;
        return Column(
          children: [
            Row(
              children: [
                if (downloadProgress.downloadStatus == DownloadStatus.downloading)
                  GetBuilder<GalleryDownloadService>(
                    id: '${logic.downloadService.galleryDownloadSpeedComputerId}::${gallery.gid}',
                    builder: (_) => Text(
                      speedComputer.speed,
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
                    ),
                  ),
                const Expanded(child: SizedBox()),
                Text(
                  '${downloadProgress.curCount}/${downloadProgress.totalCount}',
                  style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
                ),
              ],
            ),
            if (downloadProgress.downloadStatus != DownloadStatus.downloaded)
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: downloadProgress.curCount / downloadProgress.totalCount,
                  color: downloadProgress.downloadStatus == DownloadStatus.downloading
                      ? UIConfig.downloadPageProgressIndicatorColor
                      : UIConfig.downloadPageProgressIndicatorPausedColor,
                ),
              ).marginOnly(top: 4),
          ],
        );
      },
    );
  }
}
