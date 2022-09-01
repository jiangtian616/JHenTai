import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
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
import '../../../widget/focus_widget.dart';
import '../../layout/desktop/desktop_layout_page_logic.dart';
import '../../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import '../download_base_page.dart';
import 'archive_download_page_logic.dart';
import 'archive_download_page_state.dart';

class ArchiveDownloadPage extends StatelessWidget {
  final bool showMenuButton;

  ArchiveDownloadPage({Key? key, required this.showMenuButton}) : super(key: key);

  final ArchiveDownloadPageLogic logic = Get.put<ArchiveDownloadPageLogic>(ArchiveDownloadPageLogic(), permanent: true);
  final ArchiveDownloadPageState state = Get.find<ArchiveDownloadPageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: FadeIn(child: buildBody(context)),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_upward, size: 28),
        foregroundColor: Get.theme.primaryColor,
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 3,
        heroTag: null,
        onPressed: logic.scroll2Top,
      ),
    );
  }

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: CupertinoSlidingSegmentedControl<DownloadPageBodyType>(
        groupValue: DownloadPageBodyType.archive,
        children: {
          DownloadPageBodyType.download: SizedBox(
            width: 66,
            child: Center(child: Text('download'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          ),
          DownloadPageBodyType.archive: Text('archive'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          DownloadPageBodyType.local: Text('local'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        },
        onValueChanged: (value) => DownloadPageBodyTypeChangeNotification(value!).dispatch(context),
      ),
      elevation: 1,
      leadingWidth: 70,
      leading: ExcludeFocus(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMenuButton)
              IconButton(
                icon: const Icon(FontAwesomeIcons.bars, size: 20),
                onPressed: () => TapMenuButtonNotification().dispatch(context),
              ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: 88,
          child: Row(
            children: [
              ExcludeFocus(
                child: IconButton(
                  icon: Icon(Icons.play_arrow, size: 26, color: Get.theme.primaryColor),
                  onPressed: logic.archiveDownloadService.resumeAllDownloadArchive,
                  visualDensity: const VisualDensity(horizontal: -4),
                ),
              ),
              ExcludeFocus(
                child: IconButton(
                  icon: Icon(Icons.pause, size: 26, color: Get.theme.primaryColorLight),
                  onPressed: logic.archiveDownloadService.pauseAllDownloadArchive,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget buildBody(BuildContext context) {
    return GetBuilder<ArchiveDownloadService>(
      id: ArchiveDownloadService.archiveCountChangedId,
      builder: (_) => GetBuilder<ArchiveDownloadPageLogic>(
        id: ArchiveDownloadPageLogic.bodyId,
        builder: (_) => EHWheelSpeedController(
          scrollController: state.scrollController,
          child: GroupedListView<ArchiveDownloadedData, String>(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            controller: state.scrollController,
            groupBy: (archive) => logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!.group,
            groupSeparatorBuilder: _groupSeparatorBuilder,
            elements: logic.archiveDownloadService.archives,
            itemBuilder: (BuildContext context, ArchiveDownloadedData archive) => _itemBuilder(context, archive),
            sort: false,
          ),
        ),
      ),
    );
  }

  Widget _groupSeparatorBuilder(String groupName) {
    return GestureDetector(
      onTap: () => logic.toggleDisplayGroups(groupName),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Get.theme.cardColor,

          /// covered when in dark mode
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              spreadRadius: 1,
              offset: const Offset(0.3, 1),
            )
          ],
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.only(top: 5, bottom: 5, left: 5, right: 5),
        child: Row(
          children: [
            const SizedBox(width: 110, child: Center(child: Icon(Icons.folder_open))),
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Expanded(child: SizedBox()),
            GetBuilder<ArchiveDownloadPageLogic>(
              id: '${ArchiveDownloadPageLogic.groupId}::$groupName',
              builder: (_) => Icon(state.displayGroups.contains(groupName) ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right),
            ).marginOnly(right: 8),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, ArchiveDownloadedData archive) {
    String? group = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]?.group;

    return GetBuilder<ArchiveDownloadPageLogic>(
      id: '${ArchiveDownloadPageLogic.groupId}::$group',
      builder: (_) {
        if (!state.displayGroups.contains(group)) {
          return const SizedBox();
        }

        Widget child = FocusWidget(
          focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).appBarTheme.foregroundColor!))),
          handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
          handleTapEnter: () => logic.goToReadPage(archive),
          handleTapArrowRight: () => logic.goToReadPage(archive),
          child: Slidable(
            key: Key(archive.gid.toString()),
            endActionPane: _buildEndActionPane(archive),
            child: GestureDetector(
              onSecondaryTap: () => showDeleteBottomSheet(archive, context),
              onLongPress: () => showDeleteBottomSheet(archive, context),
              child: _buildCard(archive, context),
            ),
          ),
        );

        /// has not been deleted
        if (!logic.removedGidAndIsOrigin2AnimationController.containsKey(archive.gid)) {
          return child;
        }

        AnimationController controller = logic.removedGidAndIsOrigin2AnimationController[archive.gid]!;
        Animation<double> animation = logic.removedGidAndIsOrigin2Animation[archive.gid]!;

        /// has been deleted, start animation
        if (!controller.isAnimating) {
          controller.forward();
        }

        return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
      },
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
          onPressed: (_) => logic.handleChangeGroup(archive),
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
      height: 130,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,

        /// covered when in dark mode
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0.3, 1),
          )
        ],
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.only(top: 5, bottom: 5, left: 5, right: 5),
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
      onTap: () => toRoute(Routes.details, arguments: archive.galleryUrl),
      child: Obx(
        () => EHImage.network(
          containerHeight: 130,
          containerWidth: 110,
          galleryImage: GalleryImage(url: archive.coverUrl, width: archive.coverWidth, height: archive.coverHeight),
          adaptive: true,
          fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
          clearMemoryCacheWhenDispose: false,
        ),
      ),
    );
  }

  Widget _buildInfo(ArchiveDownloadedData archive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => logic.goToReadPage(archive),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoHeader(archive),
          _buildInfoCenter(archive),
          _buildInfoFooter(archive),
        ],
      ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
    );
  }

  Widget _buildInfoHeader(ArchiveDownloadedData archive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          archive.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, height: 1.2),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (archive.uploader != null)
              Text(
                archive.uploader!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ).marginOnly(top: 5),
            Text(
              DateUtil.transform2LocalTimeString(archive.publishTime),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildInfoCenter(ArchiveDownloadedData archive) {
    return Row(
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
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}::${archive.isOriginal}',
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
        border: Border.all(color: Get.theme.primaryColorLight),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(color: Get.theme.primaryColorLight, fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildButton(ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}::${archive.isOriginal}',
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
                ? Get.theme.primaryColorLight
                : Get.theme.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}::${archive.isOriginal}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = logic.archiveDownloadService.archiveDownloadInfos[archive.gid]!;
        return Column(
          children: [
            Row(
              children: [
                if (archiveDownloadInfo.archiveStatus == ArchiveStatus.downloading)
                  GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                    builder: (_) => Text(archiveDownloadInfo.speedComputer.speed, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                const Expanded(child: SizedBox()),
                if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index)
                  GetBuilder<ArchiveDownloadService>(
                    id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                    builder: (_) => Text(
                      '${byte2String(archiveDownloadInfo.speedComputer.downloadedBytes.toDouble())}/${byte2String(archive.size.toDouble())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                if (archiveDownloadInfo.archiveStatus != ArchiveStatus.downloading)
                  Text(archiveDownloadInfo.archiveStatus.name.tr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)).marginOnly(left: 8),
              ],
            ),
            if (archiveDownloadInfo.archiveStatus.index < ArchiveStatus.downloaded.index)
              SizedBox(
                height: 3,
                child: GetBuilder<ArchiveDownloadService>(
                  id: '${ArchiveDownloadService.archiveSpeedComputerId}::${archive.gid}::${archive.isOriginal}',
                  builder: (_) => LinearProgressIndicator(
                    value: archiveDownloadInfo.speedComputer.downloadedBytes / archive.size,
                    color:
                        archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index ? Get.theme.primaryColor : Get.theme.primaryColorLight,
                  ),
                ),
              ).marginOnly(top: 4),
          ],
        );
      },
    );
  }

  void showDeleteBottomSheet(ArchiveDownloadedData archive, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('changeGroup'.tr),
            onPressed: () {
              backRoute();
              logic.handleChangeGroup(archive);
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
