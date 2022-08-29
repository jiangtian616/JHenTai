import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/re_unlock_dialog.dart';

import '../../model/gallery_image.dart';
import '../../routes/routes.dart';
import '../../service/archive_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/byte_util.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import '../../widget/eh_image.dart';
import '../../widget/focus_widget.dart';
import '../layout/desktop/desktop_layout_page_logic.dart';

class ArchiveDownloadBody extends StatefulWidget {
  const ArchiveDownloadBody({Key? key}) : super(key: key);

  @override
  State<ArchiveDownloadBody> createState() => _ArchiveDownloadBodyState();
}

class _ArchiveDownloadBodyState extends State<ArchiveDownloadBody> with TickerProviderStateMixin {
  final ArchiveDownloadService archiveDownloadService = Get.find();
  final StorageService storageService = Get.find();

  final ScrollController _scrollController = ScrollController();

  final Map<int, AnimationController> removedGidAndIsOrigin2AnimationController = {};
  final Map<int, Animation<double>> removedGidAndIsOrigin2Animation = {};

  @override
  void initState() {
    if (Get.isRegistered<DesktopLayoutPageLogic>()) {
      Get.find<DesktopLayoutPageLogic>().state.scrollControllers[7] = _scrollController;
    }
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ArchiveDownloadService>(
      id: ArchiveDownloadService.archiveCountChangedId,
      builder: (_) => EHWheelSpeedController(
        scrollController: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemCount: archiveDownloadService.archives.length,
          itemBuilder: (context, index) => _itemBuilder(context, index),
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    ArchiveDownloadedData archive = archiveDownloadService.archives[index];

    Widget child = FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).appBarTheme.foregroundColor!))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => _goToReadPage(archive),
      handleTapArrowRight: () => _goToReadPage(archive),
      child: Slidable(
        key: Key(archive.gid.toString()),
        endActionPane: _buildEndActionPane(archive),
        child: GestureDetector(
          onSecondaryTap: () => _showDeleteBottomSheet(archive, context),
          onLongPress: () => _showDeleteBottomSheet(archive, context),
          child: _buildCard(archive),
        ),
      ),
    );

    /// has not been deleted
    if (!removedGidAndIsOrigin2AnimationController.containsKey(archive.gid)) {
      return child;
    }

    AnimationController controller = removedGidAndIsOrigin2AnimationController[archive.gid]!;
    Animation<double> animation = removedGidAndIsOrigin2Animation[archive.gid]!;

    /// has been deleted, start animation
    if (!controller.isAnimating) {
      controller.forward();
    }

    return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
  }

  ActionPane _buildEndActionPane(ArchiveDownloadedData archive) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.15,
      children: [
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => _handleRemoveItem(archive),
        )
      ],
    );
  }

  Widget _buildCard(ArchiveDownloadedData archive) {
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
        ),
      ),
    );
  }

  Widget _buildInfo(ArchiveDownloadedData archive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goToReadPage(archive),
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
        ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid]!;

        if (archiveDownloadInfo.archiveStatus != ArchiveStatus.needReUnlock) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: () async {
            bool? ok = await Get.dialog(const ReUnlockDialog());
            if (ok ?? false) {
              archiveDownloadService.cancelUnlockArchiveAndDownload(archive);
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
        ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid]!;
        return GestureDetector(
          onTap: () => archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
              ? archiveDownloadService.resumeDownloadArchive(archive)
              : archiveDownloadService.pauseDownloadArchive(archive),
          child: Icon(
            archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index
                ? Icons.play_arrow
                : archiveDownloadInfo.archiveStatus == ArchiveStatus.completed
                    ? Icons.done
                    : Icons.pause,
            size: 26,
            color: archiveDownloadInfo.archiveStatus == ArchiveStatus.downloading ? Get.theme.primaryColorLight : Get.theme.primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildInfoFooter(ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '${ArchiveDownloadService.archiveStatusId}::${archive.gid}::${archive.isOriginal}',
      builder: (_) {
        ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid]!;
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

  void _handleRemoveItem(ArchiveDownloadedData archive) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedGidAndIsOrigin2AnimationController.remove(archive.gid);
        removedGidAndIsOrigin2Animation.remove(archive.gid);

        Get.engine.addPostFrameCallback((_) {
          archiveDownloadService.deleteArchive(archive);
        });
      }
    });
    removedGidAndIsOrigin2AnimationController[archive.gid] = controller;
    removedGidAndIsOrigin2Animation[archive.gid] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));

    archiveDownloadService.update([ArchiveDownloadService.archiveCountChangedId]);
  }

  void _showDeleteBottomSheet(ArchiveDownloadedData archive, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              _handleRemoveItem(archive);
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

  void _goToReadPage(ArchiveDownloadedData archive) {
    if (archiveDownloadService.archiveDownloadInfos[archive.gid]?.archiveStatus != ArchiveStatus.completed) {
      return;
    }

    int readIndexRecord = storageService.read('readIndexRecord::${archive.gid}') ?? 0;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.archive,
        gid: archive.gid,
        galleryUrl: archive.galleryUrl,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: archive.pageCount,
        isOriginal: archive.isOriginal,
        images: archiveDownloadService.getUnpackedImages(archive),
      ),
    );
  }
}
