import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/mixin/scroll_to_top_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_state_mixin.dart';

import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../service/super_resolution_service.dart' as srs;
import '../../../../service/super_resolution_service.dart';
import '../../../../setting/style_setting.dart';
import '../../../../utils/byte_util.dart';
import '../../../../utils/date_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_gallery_category_tag.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/fade_shrink_widget.dart';
import '../../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../../download_base_page.dart';
import '../../mixin/archive/archive_download_page_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'archive_list_download_page_logic.dart';
import 'archive_list_download_page_state.dart';

class ArchiveListDownloadPage extends StatelessWidget with Scroll2TopPageMixin, MultiSelectDownloadPageMixin, ArchiveDownloadPageMixin {
  ArchiveListDownloadPage({Key? key}) : super(key: key);

  final ArchiveListDownloadPageLogic logic = Get.put<ArchiveListDownloadPageLogic>(ArchiveListDownloadPageLogic(), permanent: true);
  final ArchiveListDownloadPageState state = Get.find<ArchiveListDownloadPageLogic>().state;

  @override
  ArchiveDownloadPageLogicMixin get archiveDownloadPageLogic => logic;

  @override
  ArchiveDownloadPageStateMixin get archiveDownloadPageState => state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
      bottomNavigationBar: buildBottomAppBar(),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: StyleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: const DownloadPageSegmentControl(galleryType: DownloadPageGalleryType.archive),
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
              logic.archiveDownloadService.resumeAllDownloadArchive();
            }
            if (value == 3) {
              logic.archiveDownloadService.pauseAllDownloadArchive();
            }
          },
        ),
      ],
    );
  }

  Widget buildBody() {
    return GetBuilder<ArchiveDownloadService>(
      id: logic.archiveDownloadService.galleryCountChangedId,
      builder: (_) => GetBuilder<ArchiveListDownloadPageLogic>(
        id: logic.bodyId,
        builder: (_) => NotificationListener<UserScrollNotification>(
          onNotification: logic.onUserScroll,
          child: GroupList<ArchiveDownloadedData, String>(
            scrollController: state.scrollController,
            groups: logic.archiveDownloadService.allGroups,
            elements: logic.archiveDownloadService.archives,
            groupBy: (ArchiveDownloadedData archive) => logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.group ?? 'default'.tr,
            groupBuilder: (context, groupName) => _groupBuilder(context, groupName).marginAll(5),
            itemBuilder: (BuildContext context, ArchiveDownloadedData archive) => _itemBuilder(context, archive),
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
          boxShadow: [if (!Get.isDarkMode) UIConfig.downloadPageGroupShadow(context)],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SizedBox(width: UIConfig.downloadPageGroupHeaderWidth, child: Center(child: Icon(Icons.folder_open))),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GetBuilder<ArchiveListDownloadPageLogic>(
              id: '${logic.groupId}::$groupName',
              builder: (_) => GroupOpenIndicator(isOpen: state.displayGroups.contains(groupName)).marginOnly(right: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, ArchiveDownloadedData archive) {
    String? group = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.group;

    return Slidable(
      key: Key(archive.gid.toString()),
      endActionPane: _buildEndActionPane(context, archive),
      child: GestureDetector(
        onSecondaryTap: () => logic.handleLongPressOrSecondaryTapItem(archive, context),
        onLongPress: () => logic.handleLongPressOrSecondaryTapItem(archive, context),
        child: GetBuilder<ArchiveListDownloadPageLogic>(
          id: '${logic.groupId}::$group',
          builder: (_) => FadeShrinkWidget(
            show: state.displayGroups.contains(group) && !state.removedGids.contains(archive.gid),
            child: _buildCard(context, archive).marginAll(5),
            afterDisappear: () {
              if (state.removedGids.contains(archive.gid)) {
                Get.engine.addPostFrameCallback(
                  (_) => logic.archiveDownloadService.deleteArchive(archive),
                );
                state.removedGids.remove(archive.gid);
              }
            },
          ),
        ),
      ),
    );
  }

  ActionPane _buildEndActionPane(BuildContext context, ArchiveDownloadedData archive) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.3,
      children: [
        SlidableAction(
          icon: Icons.bookmark,
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (_) => logic.handleChangeArchiveGroup(archive),
        ),
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: UIConfig.alertColor(context),
          backgroundColor: UIConfig.downloadPageActionBackGroundColor(context),
          onPressed: (BuildContext context) => logic.handleRemoveItem(archive),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveListDownloadPageLogic>(
      id: '${logic.itemCardId}::${archive.gid}',
      builder: (_) => Container(
        decoration: state.selectedGids.contains(archive.gid)
            ? BoxDecoration(
                color: UIConfig.downloadPageCardSelectedColor(context),
                borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
              )
            : null,
        height: UIConfig.downloadPageCardHeight,
        child: Row(
          children: [
            _buildCover(archive),
            _buildInfo(context, archive),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ArchiveDownloadedData archive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(
        Routes.details,
        arguments: {'gid': archive.gid, 'galleryUrl': archive.galleryUrl},
      ),
      child: EHImage(
        galleryImage: GalleryImage(url: archive.coverUrl),
        containerWidth: UIConfig.downloadPageCoverWidth,
        containerHeight: UIConfig.downloadPageCoverHeight,
        borderRadius: BorderRadius.circular(UIConfig.downloadPageCardBorderRadius),
        fit: BoxFit.fitWidth,
        maxBytes: 2 * 1024 * 1024,
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ArchiveDownloadedData archive) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => logic.handleTapItem(archive),
        child: Container(
          padding: const EdgeInsets.only(left: 6, right: 10, bottom: 6, top: 6),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoHeader(context, archive),
                  const Expanded(child: SizedBox()),
                  _buildInfoCenter(context, archive),
                  const Expanded(child: SizedBox()),
                  _buildInfoFooter(context, archive),
                ],
              ),
              if (state.selectedGids.contains(archive.gid)) const Positioned(child: Center(child: Icon(Icons.check_circle))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoHeader(BuildContext context, ArchiveDownloadedData archive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          archive.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: UIConfig.downloadPageCardTitleSize, height: 1.2),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (archive.uploader != null)
              Text(
                archive.uploader!,
                style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
              ),
            Text(
              DateUtil.transform2LocalTimeString(archive.publishTime),
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
            ),
          ],
        ).marginOnly(top: 5),
      ],
    );
  }

  Widget _buildInfoCenter(BuildContext context, ArchiveDownloadedData archive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGalleryCategoryTag(category: archive.category),
        const Expanded(child: SizedBox()),
        _buildReUnlockButton(context, archive),
        _buildIsOriginal(context, archive),
        _buildSuperResolutionLabel(context, archive),
        _buildButton(context, archive),
      ],
    );
  }

  Widget _buildReUnlockButton(BuildContext context, ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;

        if (archiveDownloadInfo.archiveStatus != ArchiveStatus.needReUnlock) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: () => logic.handleReUnlockArchive(archive),
          child: Icon(Icons.lock_open, size: 18, color: UIConfig.alertColor(context)),
        ).marginSymmetric(horizontal: 6);
      },
    );
  }

  Widget _buildIsOriginal(BuildContext context, ArchiveDownloadedData archive) {
    bool isOriginal = archive.isOriginal;
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

  Widget _buildSuperResolutionLabel(BuildContext context, ArchiveDownloadedData archive) {
    return GetBuilder<srs.SuperResolutionService>(
      id: '${srs.SuperResolutionService.superResolutionId}::${archive.gid}',
      builder: (_) {
        srs.SuperResolutionInfo? superResolutionInfo = Get.find<SuperResolutionService>().get(archive.gid, srs.SuperResolutionType.archive);

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

  Widget _buildButton(BuildContext context, ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;
        return GestureDetector(
          onTap: () => archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
              ? logic.archiveDownloadService.resumeDownloadArchive(archive)
              : logic.archiveDownloadService.pauseDownloadArchive(archive),
          child: Icon(
            archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                ? Icons.play_arrow
                : archiveDownloadInfo.archiveStatus == ArchiveStatus.completed
                    ? Icons.done
                    : Icons.pause,
            size: 26,
            color: UIConfig.resumePauseButtonColor(context),
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(BuildContext context, ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (archiveDownloadInfo.archiveStatus == ArchiveStatus.downloading)
                  GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                    builder: (_) => Text(
                      archiveDownloadInfo.speedComputer.speed,
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
                    ),
                  ),
                const Expanded(child: SizedBox()),
                if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index)
                  GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                    builder: (_) => Text(
                      '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())}/${byte2String(archive.size.toDouble())}',
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context)),
                    ),
                  ),
                if (archiveDownloadInfo.archiveStatus != ArchiveStatus.downloading)
                  Text(
                    archiveDownloadInfo.archiveStatus.name.tr,
                    style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor(context), height: 1),
                  ).marginOnly(left: 8),
              ],
            ),
            if (archiveDownloadInfo.archiveStatus.index < ArchiveStatus.downloaded.index)
              SizedBox(
                height: UIConfig.downloadPageProgressIndicatorHeight,
                child: GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                  builder: (_) => LinearProgressIndicator(
                    value: archiveDownloadInfo.speedComputer.downloadedBytes / archive.size,
                    color: archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                        ? UIConfig.downloadPageProgressPausedIndicatorColor(context)
                        : UIConfig.downloadPageProgressIndicatorColor(context),
                  ),
                ),
              ).marginOnly(top: 6),
          ],
        );
      },
    );
  }
}
