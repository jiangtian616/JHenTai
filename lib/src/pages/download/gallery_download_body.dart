import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../model/gallery_image.dart';
import '../../model/read_page_info.dart';
import '../../routes/routes.dart';
import '../../service/gallery_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_wheel_speed_controller.dart';
import '../../widget/focus_widget.dart';
import '../layout/desktop/desktop_layout_page_logic.dart';

class GalleryDownloadBody extends StatefulWidget {
  const GalleryDownloadBody({Key? key}) : super(key: key);

  @override
  State<GalleryDownloadBody> createState() => _GalleryDownloadBodyState();
}

class _GalleryDownloadBodyState extends State<GalleryDownloadBody> with TickerProviderStateMixin {
  final GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
  final StorageService storageService = Get.find<StorageService>();

  final ScrollController _scrollController = ScrollController();

  final Map<int, AnimationController> removedGid2AnimationController = {};
  final Map<int, Animation<double>> removedGid2Animation = {};

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
    for (AnimationController controller in removedGid2AnimationController.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<GalleryDownloadService>(
      id: galleryCountOrOrderChangedId,
      builder: (_) => EHWheelSpeedController(
        scrollController: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemCount: downloadService.gallerys.length,
          itemBuilder: (context, index) => _itemBuilder(context, index),
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    GalleryDownloadedData gallery = downloadService.gallerys[index];

    Widget child = FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).appBarTheme.foregroundColor!))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => _goToReadPage(gallery),
      handleTapArrowRight: () => _goToReadPage(gallery),
      child: Slidable(
        key: Key(gallery.gid.toString()),
        endActionPane: _buildEndActionPane(gallery),
        child: GestureDetector(
          onLongPress: () => _showBottomSheet(gallery, index, context),
          child: _buildCard(gallery),
        ),
      ),
    );

    /// has not been deleted
    if (!removedGid2AnimationController.containsKey(gallery.gid)) {
      return child;
    }

    AnimationController controller = removedGid2AnimationController[gallery.gid]!;
    Animation<double> animation = removedGid2Animation[gallery.gid]!;

    /// has been deleted, start animation
    if (!controller.isAnimating) {
      controller.forward();
    }

    return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
  }

  ActionPane _buildEndActionPane(GalleryDownloadedData gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.3,
      children: [
        SlidableAction(
          icon: FontAwesomeIcons.sort,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => _showPrioritySheet(gallery, context),
        ),
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => _handleRemoveItem(context, gallery, true),
        )
      ],
    );
  }

  Widget _buildCard(GalleryDownloadedData gallery) {
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
      onTap: () => toRoute(Routes.details, arguments: gallery.galleryUrl),
      child: GetBuilder<GalleryDownloadService>(
        id: '$downloadImageUrlId::${gallery.gid}::0',
        builder: (_) {
          GalleryImage? image = downloadService.galleryDownloadInfos[gallery.gid]?.images[0];

          /// cover is the first image, if we haven't downloaded first image, then return a [CupertinoActivityIndicator]
          if (image?.downloadStatus != DownloadStatus.downloaded) {
            return const SizedBox(
              height: 130,
              width: 110,
              child: CupertinoActivityIndicator(),
            );
          }

          return Obx(() => EHImage.file(
                containerHeight: 130,
                containerWidth: 110,
                galleryImage: image!,
                adaptive: true,
                fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
              ));
        },
      ),
    );
  }

  Widget _buildInfo(GalleryDownloadedData gallery) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goToReadPage(gallery),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoHeader(gallery),
            const Expanded(child: SizedBox()),
            _buildInfoCenter(gallery),
            _buildInfoFooter(gallery).marginOnly(top: 4),
          ],
        ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
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
          style: const TextStyle(fontSize: 15, height: 1.2),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (gallery.uploader != null)
              Text(
                gallery.uploader!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ).marginOnly(top: 5),
            Text(
              DateUtil.transform2LocalTimeString(gallery.publishTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildInfoCenter(GalleryDownloadedData gallery) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            const Expanded(child: SizedBox()),
            _buildIsOriginal(gallery).marginOnly(right: 10),
            _buildPriority(gallery).marginOnly(right: 6),
            GetBuilder<GalleryDownloadService>(
              id: '$galleryDownloadProgressId::${gallery.gid}',
              builder: (_) {
                DownloadStatus downloadStatus = downloadService.galleryDownloadInfos[gallery.gid]!.downloadProgress.downloadStatus;
                return GestureDetector(
                  onTap: downloadStatus == DownloadStatus.switching
                      ? null
                      : () {
                          downloadStatus == DownloadStatus.paused
                              ? downloadService.resumeDownloadGallery(gallery)
                              : downloadService.pauseDownloadGallery(gallery);
                        },
                  child: downloadStatus == DownloadStatus.switching
                      ? const SizedBox(height: 26, child: CupertinoActivityIndicator(radius: 10))
                      : Icon(
                          downloadStatus == DownloadStatus.paused
                              ? Icons.play_arrow
                              : downloadStatus == DownloadStatus.downloading
                                  ? Icons.pause
                                  : Icons.done,
                          size: 26,
                          color: downloadStatus == DownloadStatus.downloading ? Get.theme.primaryColorLight : Get.theme.primaryColor,
                        ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoFooter(GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '$galleryDownloadProgressId::${gallery.gid}',
      builder: (_) {
        GalleryDownloadProgress downloadProgress = downloadService.galleryDownloadInfos[gallery.gid]!.downloadProgress;
        GalleryDownloadSpeedComputer speedComputer = downloadService.galleryDownloadInfos[gallery.gid]!.speedComputer;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (downloadProgress.downloadStatus == DownloadStatus.downloading)
                  GetBuilder<GalleryDownloadService>(
                    id: '$galleryDownloadSpeedComputerId::${gallery.gid}',
                    builder: (logic) {
                      return Text(
                        speedComputer.speed,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      );
                    },
                  ),
                const Expanded(child: SizedBox()),
                Text(
                  '${downloadProgress.curCount}/${downloadProgress.totalCount}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (downloadProgress.downloadStatus != DownloadStatus.downloaded)
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: downloadProgress.curCount / downloadProgress.totalCount,
                  color: downloadProgress.downloadStatus == DownloadStatus.downloading ? Get.theme.primaryColorLight : Get.theme.primaryColor,
                ),
              ).marginOnly(top: 4),
          ],
        );
      },
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
        border: Border.all(color: Get.theme.primaryColorLight),
      ),
      child: Text(
        'original'.tr,
        style: TextStyle(
          color: Get.theme.primaryColorLight,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildPriority(GalleryDownloadedData gallery) {
    int? priority = downloadService.galleryDownloadInfos[gallery.gid]?.priority;
    if (priority == null) {
      return const SizedBox();
    }

    switch (priority) {
      case 1:
        return Text('①', style: TextStyle(color: Get.theme.primaryColorLight, fontWeight: FontWeight.bold));
      case 2:
        return Text('②', style: TextStyle(color: Get.theme.primaryColorLight, fontWeight: FontWeight.bold));
      case 3:
        return Text('③', style: TextStyle(color: Get.theme.primaryColorLight, fontWeight: FontWeight.bold));
      case GalleryDownloadService.defaultDownloadGalleryPriority:
        return const SizedBox();
      case 5:
        return Text('⑤', style: TextStyle(color: Get.theme.primaryColorLight, fontWeight: FontWeight.bold));
      default:
        return const SizedBox();
    }
  }

  void _showBottomSheet(GalleryDownloadedData gallery, int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('reDownload'.tr),
            onPressed: () {
              _handleReDownloadItem(context, index);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('deleteTask'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              _handleRemoveItem(context, gallery, false);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('deleteTaskAndImages'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              _handleRemoveItem(context, gallery, true);
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

  void _showPrioritySheet(GalleryDownloadedData gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 1 (${'highest'.tr})'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 1,
            onPressed: () {
              _handleAssignPriority(gallery, 1);
              backRoute();
            },
          ),
          ...[2, 3]
              .map((i) => CupertinoActionSheetAction(
                    child: Text('${'priority'.tr} : $i'),
                    isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == i,
                    onPressed: () {
                      _handleAssignPriority(gallery, i);
                      backRoute();
                    },
                  ))
              .toList(),
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 4 (${'default'.tr})'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 4,
            onPressed: () {
              _handleAssignPriority(gallery, 4);
              backRoute();
            },
          ),
          CupertinoActionSheetAction(
            child: Text('${'priority'.tr} : 5'),
            isDefaultAction: downloadService.galleryDownloadInfos[gallery.gid]?.priority == 5,
            onPressed: () {
              _handleAssignPriority(gallery, 5);
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

  void _handleRemoveItem(BuildContext context, GalleryDownloadedData gallery, bool deleteImages) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedGid2AnimationController.remove(gallery.gid);
        removedGid2Animation.remove(gallery.gid);

        Get.engine.addPostFrameCallback((_) {
          downloadService.deleteGallery(gallery, deleteImages: deleteImages);
        });
      }
    });
    removedGid2AnimationController[gallery.gid] = controller;
    removedGid2Animation[gallery.gid] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));

    downloadService.update([galleryCountOrOrderChangedId]);
  }

  void _handleAssignPriority(GalleryDownloadedData gallery, int? priority) {
    downloadService.assignPriority(gallery, priority);
  }

  void _handleReDownloadItem(BuildContext context, int index) {
    downloadService.reDownloadGallery(downloadService.gallerys[index]);
  }

  void _goToReadPage(GalleryDownloadedData gallery) {
    int readIndexRecord = storageService.read('readIndexRecord::${gallery.gid}') ?? 0;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.downloaded,
        gid: gallery.gid,
        galleryUrl: gallery.galleryUrl,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: gallery.pageCount,
      ),
    );
  }
}
