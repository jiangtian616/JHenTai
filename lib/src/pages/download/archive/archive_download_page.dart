import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/widget/re_unlock_dialog.dart';

import '../../../model/gallery_image.dart';
import '../../../routes/routes.dart';
import '../../../service/archive_download_service.dart';
import '../../../setting/style_setting.dart';
import '../../../utils/byte_util.dart';
import '../../../utils/date_util.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_gallery_category_tag.dart';
import '../../../widget/eh_image.dart';
import '../../../widget/fade_shrink_widget.dart';
import '../../../widget/focus_widget.dart';
import '../../layout/desktop/desktop_layout_page_logic.dart';
import '../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../download_base_page.dart';
import 'archive_download_page_logic.dart';
import 'archive_download_page_state.dart';

class ArchiveDownloadPage extends StatelessWidget {
  ArchiveDownloadPage({Key? key, this.showMenuButton = false}) : super(key: key);

  final bool showMenuButton;
  final ArchiveDownloadPageLogic logic = Get.put<ArchiveDownloadPageLogic>(ArchiveDownloadPageLogic(), permanent: true);
  final ArchiveDownloadPageState state = Get.find<ArchiveDownloadPageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(context),
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
      leading: StyleSetting.isInV2Layout
          ? IconButton(icon: const Icon(FontAwesomeIcons.bars, size: 20), onPressed: () => TapMenuButtonNotification().dispatch(context))
          : null,
      titleSpacing: 0,
      title: const EHDownloadPageSegmentControl(bodyType: DownloadPageBodyType.archive),
      actions: [
        ExcludeFocus(
          child: IconButton(
            icon: Icon(Icons.play_arrow, size: 26, color: UIConfig.resumeButtonColor),
            onPressed: logic.archiveDownloadService.resumeAllDownloadArchive,
            visualDensity: const VisualDensity(horizontal: -4),
          ),
        ),
        ExcludeFocus(
          child: IconButton(
            icon: Icon(Icons.pause, size: 26, color: UIConfig.pauseButtonColor),
            onPressed: logic.archiveDownloadService.pauseAllDownloadArchive,
          ),
        ),
      ],
    );
  }

  Widget buildBody(BuildContext context) {
    return GetBuilder<ArchiveDownloadService>(
      id: ArchiveDownloadService.archiveCountChangedId,
      builder: (_) => GetBuilder<ArchiveDownloadPageLogic>(
        id: ArchiveDownloadPageLogic.bodyId,
        builder: (_) => GroupList<ArchiveDownloadedData, String>(
          scrollController: state.scrollController,
          groups: logic.archiveDownloadService.allGroups,
          elements: logic.archiveDownloadService.archives,
          groupBy: (ArchiveDownloadedData archive) => logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.group ?? 'default'.tr,
          groupBuilder: (groupName) => _groupBuilder(groupName).marginAll(5),
          itemBuilder: (BuildContext context, ArchiveDownloadedData archive) => _itemBuilder(context, archive),
        ),
      ),
    );
  }

  Widget _groupBuilder(String groupName) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      onLongPress: () => logic.handleLongPressGroup(groupName),
      onSecondaryTap: () => logic.handleLongPressGroup(groupName),
      child: Container(
        height: UIConfig.downloadPageGroupHeight,
        decoration: BoxDecoration(
          color: UIConfig.downloadPageGroupColor,
          boxShadow: [UIConfig.downloadPageGroupShadow],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const SizedBox(width: UIConfig.downloadPageGroupHeaderWidth, child: Center(child: Icon(Icons.folder_open))),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GetBuilder<ArchiveDownloadPageLogic>(
              id: '${ArchiveDownloadPageLogic.groupId}::$groupName',
              builder: (_) => GroupOpenIndicator(isOpen: state.displayGroups.contains(groupName)).marginOnly(right: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, ArchiveDownloadedData archive) {
    String? group = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.group;

    return GetBuilder<ArchiveDownloadPageLogic>(
      id: '${ArchiveDownloadPageLogic.groupId}::$group',
      builder: (_) => FocusWidget(
        focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).colorScheme.onBackground))),
        handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
        handleTapEnter: () => logic.goToReadPage(archive),
        handleTapArrowRight: () => logic.goToReadPage(archive),
        child: Slidable(
          key: Key(archive.gid.toString()),
          endActionPane: _buildEndActionPane(archive),
          child: GestureDetector(
            onSecondaryTap: () => showArchiveBottomSheet(archive, context),
            onLongPress: () => showArchiveBottomSheet(archive, context),
            child: FadeShrinkWidget(
              show: state.displayGroups.contains(group),
              child: FadeShrinkWidget(
                show: !state.removedGids.contains(archive.gid),
                child: _buildCard(archive, context).marginAll(5),
                afterDisappear: () {
                  Get.engine.addPostFrameCallback(
                    (_) => logic.archiveDownloadService.deleteArchive(archive),
                  );
                  state.removedGids.remove(archive.gid);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  ActionPane _buildEndActionPane(ArchiveDownloadedData archive) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.3,
      children: [
        SlidableAction(
          icon: Icons.bookmark,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (_) => logic.handleChangeArchiveGroup(archive),
        ),
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => logic.handleRemoveItem(archive),
        ),
      ],
    );
  }

  Widget _buildCard(ArchiveDownloadedData archive, BuildContext context) {
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
            _buildCover(archive),
            Expanded(child: _buildInfo(archive)),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ArchiveDownloadedData archive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toRoute(Routes.details, arguments: {'galleryUrl': archive.galleryUrl}),
      child: EHImage.network(
        containerWidth: UIConfig.downloadPageCoverWidth,
        containerHeight: UIConfig.downloadPageCoverHeight,
        fit: BoxFit.fitWidth,
        galleryImage: GalleryImage(
          url: archive.coverUrl,
          width: archive.coverWidth,
          height: archive.coverHeight,
        ),
      ),
    );
  }

  Widget _buildInfo(ArchiveDownloadedData archive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => logic.goToReadPage(archive),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoHeader(archive),
          const Expanded(child: SizedBox()),
          _buildInfoCenter(archive),
          const Expanded(child: SizedBox()),
          _buildInfoFooter(archive),
        ],
      ).paddingOnly(left: 6, right: 10, bottom: 6, top: 6),
    );
  }

  Widget _buildInfoHeader(ArchiveDownloadedData archive) {
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
                style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
              ),
            Text(
              DateUtil.transform2LocalTimeString(archive.publishTime),
              style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
            ),
          ],
        ).marginOnly(top: 5),
      ],
    );
  }

  Widget _buildInfoCenter(ArchiveDownloadedData archive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGalleryCategoryTag(category: archive.category),
        const Expanded(child: SizedBox()),
        _buildReUnlockButton(archive).marginOnly(right: 10),
        _buildIsOriginal(archive).marginOnly(right: 6),
        _buildButton(archive),
      ],
    );
  }

  Widget _buildReUnlockButton(ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;

        if (archiveDownloadInfo.archiveStatus != ArchiveStatus.needReUnlock) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: () async {
            bool? ok = await Get.dialog(const ReUnlockDialog());
            if (ok ?? false) {
              logic.archiveDownloadService.cancelUnlockArchiveAndDownload(archive);
            }
          },
          child: const Icon(Icons.lock_open, size: 18, color: Colors.red),
        );
      },
    );
  }

  Widget _buildIsOriginal(ArchiveDownloadedData archive) {
    bool isOriginal = archive.isOriginal;
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

  Widget _buildButton(ArchiveDownloadedData archive) {
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
            color: (archiveDownloadInfo.archiveStatus.index >= ArchiveStatus.unlocking.index &&
                    archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index)
                ? UIConfig.pauseButtonColor
                : UIConfig.resumeButtonColor,
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(ArchiveDownloadedData archive) {
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
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
                    ),
                  ),
                const Expanded(child: SizedBox()),
                if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index)
                  GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                    builder: (_) => Text(
                      '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())}/${byte2String(archive.size.toDouble())}',
                      style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor),
                    ),
                  ),
                if (archiveDownloadInfo.archiveStatus != ArchiveStatus.downloading)
                  Text(
                    archiveDownloadInfo.archiveStatus.name.tr,
                    style: TextStyle(fontSize: UIConfig.downloadPageCardTextSize, color: UIConfig.downloadPageCardTextColor, height: 1),
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
                        ? UIConfig.downloadPageProgressIndicatorPausedColor
                        : UIConfig.downloadPageProgressIndicatorColor,
                  ),
                ),
              ).marginOnly(top: 6),
          ],
        );
      },
    );
  }

  void showArchiveBottomSheet(ArchiveDownloadedData archive, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('changeGroup'.tr),
            onPressed: () {
              backRoute();
              logic.handleChangeArchiveGroup(archive);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              logic.handleRemoveItem(archive);
              backRoute();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
      ),
    );
  }
}
