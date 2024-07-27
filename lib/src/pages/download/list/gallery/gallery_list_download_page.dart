import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_mixin.dart';
import 'package:jhentai/src/service/super_resolution_service.dart' as srs;
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/grouped_list.dart';
import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../service/gallery_download_service.dart';
import '../../../../service/super_resolution_service.dart';
import '../../../../setting/performance_setting.dart';
import '../../../../utils/date_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_gallery_category_tag.dart';
import '../../../../widget/eh_image.dart';
import '../../../details/details_page_logic.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../../download_base_page.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../../mixin/gallery/gallery_download_page_logic_mixin.dart';
import '../../mixin/gallery/gallery_download_page_state_mixin.dart';
import 'gallery_list_download_page_logic.dart';
import 'gallery_list_download_page_state.dart';

class GalleryListDownloadPage extends StatelessWidget with Scroll2TopPageMixin, MultiSelectDownloadPageMixin, GalleryDownloadPageMixin {
  GalleryListDownloadPage({Key? key}) : super(key: key);

  final GalleryListDownloadPageLogic logic = Get.put<GalleryListDownloadPageLogic>(GalleryListDownloadPageLogic(), permanent: true);
  final GalleryListDownloadPageState state = Get.find<GalleryListDownloadPageLogic>().state;

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
      leading: styleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: const DownloadPageSegmentControl(galleryType: DownloadPageGalleryType.download),
      actions: [
        PopupMenuButton(
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.grid_view), const SizedBox(width: 12), Text('switch2GridMode'.tr)],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.done_all), const SizedBox(width: 12), Text('multiSelect'.tr)],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.play_arrow), const SizedBox(width: 12), Text('resumeAllTasks'.tr)],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.pause), const SizedBox(width: 12), Text('pauseAllTasks'.tr)],
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const Icon(Icons.search), const SizedBox(width: 12), Text('search'.tr)],
                ),
              ),
            ];
          },
          onSelected: (value) {
            if (value == 0) {
              DownloadPageBodyTypeChangeNotification(bodyType: DownloadPageBodyType.grid).dispatch(context);
            }
            if (value == 1) {
              logic.enterSelectMode();
            }
            if (value == 2) {
              logic.downloadService.resumeAllDownloadGallery();
            }
            if (value == 3) {
              logic.downloadService.pauseAllDownloadGallery();
            }
            if (value == 4) {
              toRoute(Routes.downloadSearch);
            }
          },
        ),
      ],
    );
  }

  Widget buildBody(BuildContext context) {
    return GetBuilder<GalleryDownloadService>(
      id: logic.downloadService.galleryCountChangedId,
      builder: (_) => GetBuilder<GalleryListDownloadPageLogic>(
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: FutureBuilder(
            future: state.displayGroupsCompleter.future,
            builder: (_, __) => !state.displayGroupsCompleter.isCompleted
                ? UIConfig.loadingAnimation(context).center()
                : GroupedList<String, GalleryDownloadedData>(
                    maxGalleryNum4Animation: performanceSetting.maxGalleryNum4Animation.value,
                    scrollController: state.scrollController,
                    controller: state.groupedListController,
                    groups: Map.fromEntries(logic.downloadService.allGroups.map((e) => MapEntry(e, state.displayGroups.contains(e)))),
                    elements: logic.downloadService.gallerys,
                    elementGroup: (GalleryDownloadedData gallery) => logic.downloadService.galleryDownloadInfos[gallery.gid]!.group,
                    groupBuilder: (context, groupName, isOpen) => _groupBuilder(context, groupName, isOpen).marginAll(5),
                    elementBuilder: (BuildContext context, String group, GalleryDownloadedData gallery, isOpen) => _itemBuilder(context, gallery),
                    groupUniqueKey: (String group) => group,
                    elementUniqueKey: (GalleryDownloadedData gallery) => gallery.gid.toString(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _groupBuilder(BuildContext context, String groupName, bool isOpen) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondaryTap: () => logic.handleLongPressGroup(groupName),
      child: Container(
        height: UIConfig.groupListHeight,
        decoration: BoxDecoration(
          color: UIConfig.groupListColor(context),
          boxShadow: [if (!Get.isDarkMode) UIConfig.groupListShadow(context)],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SizedBox(width: UIConfig.downloadPageGroupHeaderWidth, child: Center(child: Icon(Icons.folder_open))),
            Text(
              '$groupName${'(' + logic.downloadService.gallerysWithGroup(groupName).length.toString() + ')'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Expanded(child: SizedBox()),
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
        onSecondaryTap: () => logic.handleLongPressOrSecondaryTapItem(gallery, context),
        onLongPress: () => logic.handleLongPressOrSecondaryTapItem(gallery, context),
        child: _buildCard(context, gallery).marginAll(5),
      ),
    );
  }

  ActionPane _buildEndActionPane(BuildContext context, GalleryDownloadedData gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.4,
      children: [
        SlidableAction(
          icon: Icons.bookmark,
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (_) => logic.handleChangeGroup(gallery),
        ),
        SlidableAction(
          icon: FontAwesomeIcons.sort,
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (BuildContext context) => logic.showPrioritySheet(gallery, context),
        ),
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: UIConfig.alertColor(context),
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (BuildContext context) => logic.handleRemoveItem(gallery, true, context),
        )
      ],
    );
  }

  Widget _buildCard(BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<GalleryListDownloadPageLogic>(
      id: '${logic.itemCardId}::${gallery.gid}',
      builder: (_) => Container(
        height: UIConfig.downloadPageCardHeight,
        decoration: state.selectedGids.contains(gallery.gid)
            ? BoxDecoration(
                color: UIConfig.downloadPageCardSelectedColor(context),
                borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
              )
            : null,
        child: Row(
          children: [
            _buildCover(context, gallery),
            _buildInfo(context, gallery),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, GalleryDownloadedData gallery) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(
        Routes.details,
        arguments: DetailsPageArgument(galleryUrl: GalleryUrl.parse(gallery.galleryUrl)),
      ),
      child: GetBuilder<GalleryDownloadService>(
        id: '${logic.downloadService.downloadImageUrlId}::${gallery.gid}::0',
        builder: (_) {
          GalleryImage? image = logic.downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

          /// cover is the first image, if we haven't downloaded first image, then return a [UIConfig.loadingAnimation]
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
      ),
    );
  }

  Widget _buildInfo(BuildContext context, GalleryDownloadedData gallery) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.handleTapItem(gallery),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 6, right: 10, bottom: 6, top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoHeader(context, gallery),
                  const Expanded(child: SizedBox()),
                  _buildInfoCenter(context, gallery),
                  const Expanded(child: SizedBox()),
                  _buildInfoFooter(context, gallery),
                ],
              ),
            ),
            if (state.selectedGids.contains(gallery.gid)) const Positioned(child: Center(child: Icon(Icons.check_circle))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader(BuildContext context, GalleryDownloadedData gallery) {
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
                style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
              ),
            Text(
              preferenceSetting.showUtcTime.isTrue ? gallery.publishTime : DateUtil.transformUtc2LocalTimeString(gallery.publishTime),
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
            ),
          ],
        ).marginOnly(top: 5),
      ],
    );
  }

  Widget _buildInfoCenter(BuildContext context, GalleryDownloadedData gallery) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGalleryCategoryTag(category: gallery.category),
        const Expanded(child: SizedBox()),
        _buildIsOriginal(context, gallery),
        _buildSuperResolutionLabel(context, gallery),
        _buildPriority(context, gallery),
        _buildButton(context, gallery),
      ],
    );
  }

  Widget _buildIsOriginal(BuildContext context, GalleryDownloadedData gallery) {
    bool isOriginal = gallery.downloadOriginalImage;
    if (!isOriginal) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildSuperResolutionLabel(BuildContext context, GalleryDownloadedData gallery) {
    return GetBuilder<srs.SuperResolutionService>(
      id: '${srs.SuperResolutionService.superResolutionId}::${gallery.gid}',
      builder: (_) {
        srs.SuperResolutionInfo? superResolutionInfo = superResolutionService.get(gallery.gid, srs.SuperResolutionType.gallery);

        if (superResolutionInfo == null) {
          return const SizedBox();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: superResolutionInfo.status == srs.SuperResolutionStatus.success ? null : BorderRadius.circular(4),
            border: Border.all(color: UIConfig.resumePauseButtonColor(context)),
            shape: superResolutionInfo.status == srs.SuperResolutionStatus.success ? BoxShape.circle : BoxShape.rectangle,
          ),
          child: Text(
            superResolutionInfo.status == srs.SuperResolutionStatus.paused
                ? 'AI'
                : superResolutionInfo.status == srs.SuperResolutionStatus.success
                    ? 'AI'
                    : 'AI(${superResolutionInfo.imageStatuses.fold<int>(0, (previousValue, element) => previousValue + (element == srs.SuperResolutionStatus.success ? 1 : 0))}/${superResolutionInfo.imageStatuses.length})',
            style: TextStyle(
              fontSize: 9,
              color: UIConfig.resumePauseButtonColor(context),
              decoration: superResolutionInfo.status == srs.SuperResolutionStatus.paused ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriority(BuildContext context, GalleryDownloadedData gallery) {
    int? priority = logic.downloadService.galleryDownloadInfos[gallery.gid]?.priority;
    if (priority == null) {
      return const SizedBox();
    }

    switch (priority) {
      case 1:
        return Text('①', style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold)).marginSymmetric(horizontal: 6);
      case 2:
        return Text('②', style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold)).marginSymmetric(horizontal: 6);
      case 3:
        return Text('③', style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold)).marginSymmetric(horizontal: 6);
      case GalleryDownloadService.defaultDownloadGalleryPriority:
        return const SizedBox();
      case 5:
        return Text('⑤', style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.bold)).marginSymmetric(horizontal: 6);
      default:
        return const SizedBox();
    }
  }

  Widget _buildButton(BuildContext context, GalleryDownloadedData gallery) {
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
            color: UIConfig.resumePauseButtonColor(context),
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(BuildContext context, GalleryDownloadedData gallery) {
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
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
                    ),
                  ),
                const Expanded(child: SizedBox()),
                Text(
                  '${downloadProgress.curCount}/${downloadProgress.totalCount}',
                  style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
                ),
              ],
            ),
            if (downloadProgress.downloadStatus != DownloadStatus.downloaded)
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: downloadProgress.curCount / downloadProgress.totalCount,
                  color: UIConfig.downloadPageProgressIndicatorColor(context),
                ),
              ).marginOnly(top: 4),
          ],
        );
      },
    );
  }
}
