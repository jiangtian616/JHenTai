import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/focus_widget.dart';

import '../../model/download_progress.dart';
import '../../model/gallery_image.dart';
import '../../routes/routes.dart';
import '../../service/storage_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/date_util.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_gallery_category_tag.dart';
import '../../widget/eh_image.dart';
import '../layout/desktop/desktop_layout_page_logic.dart';

class GalleryDownloadBody extends StatefulWidget {
  const GalleryDownloadBody({Key? key}) : super(key: key);

  @override
  State<GalleryDownloadBody> createState() => _GalleryDownloadBodyState();
}

class _GalleryDownloadBodyState extends State<GalleryDownloadBody> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final GalleryDownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();

  late int gallerysCount;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    gallerysCount = downloadService.gallerys.length;
    if (Get.isRegistered<DesktopLayoutPageLogic>()) {
      Get.find<DesktopLayoutPageLogic>().state.scrollControllers[7] = _scrollController;
    }
    super.initState();
  }

  @override
  void activate() {
    super.activate();
    if (Get.isRegistered<DesktopLayoutPageLogic>()) {
      Get.find<DesktopLayoutPageLogic>().state.scrollControllers[7] = _scrollController;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<GalleryDownloadService>(
      initState: _listen2AddItem,
      builder: (_) => EHWheelSpeedController(
        scrollController: _scrollController,
        child: AnimatedList(
          key: _listKey,
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          initialItemCount: gallerysCount,
          itemBuilder: (context, index, animation) => _itemBuilder(context, index),
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    GalleryDownloadedData gallery = downloadService.gallerys[index];
    return FocusWidget(
      decoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).appBarTheme.foregroundColor!))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => _goToReadPage(gallery),
      handleTapArrowRight: () => _goToReadPage(gallery),
      child: Slidable(
        key: Key(gallery.gid.toString()),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.15,
          children: [
            SlidableAction(
              icon: Icons.delete,
              foregroundColor: Colors.red,
              backgroundColor: Get.theme.scaffoldBackgroundColor,
              onPressed: (BuildContext context) => _handleRemoveItem(context, index),
            )
          ],
        ),
        child: GestureDetector(
          onLongPress: () => _showDeleteBottomSheet(gallery, index, context),
          child: Container(
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
            margin: const EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Row(
                children: [
                  _buildCover(gallery, context),
                  _buildInfo(gallery),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _removeItemBuilder() {
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
      margin: const EdgeInsets.only(top: 5, bottom: 5, left: 10, right: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(),
      ),
    );
  }

  Widget _buildCover(GalleryDownloadedData gallery, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toNamed(Routes.details, arguments: gallery.galleryUrl),
      child: GetBuilder<GalleryDownloadService>(
        id: '$imageUrlId::${gallery.gid}::0',
        builder: (_) {
          GalleryImage? image = downloadService.gid2Images[gallery.gid]![0];

          /// cover is the first image, if we haven't downloaded first image, then return a [CupertinoActivityIndicator]
          if (image?.downloadStatus != DownloadStatus.downloaded) {
            return const SizedBox(
              height: 130,
              width: 110,
              child: CupertinoActivityIndicator(),
            );
          }

          return Obx(() {
            return EHImage.file(
              containerHeight: 130,
              containerWidth: 110,
              galleryImage: image!,
              adaptive: true,
              fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
            );
          });
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
            _buildHeader(gallery),
            const Expanded(child: SizedBox()),
            _buildCenter(gallery),
            _buildFooter(gallery).marginOnly(top: 4),
          ],
        ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
      ),
    );
  }

  Widget _buildHeader(GalleryDownloadedData gallery) {
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

  Widget _buildCenter(GalleryDownloadedData gallery) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            GetBuilder<GalleryDownloadService>(
              id: '$galleryDownloadProgressId::${gallery.gid}',
              builder: (_) {
                DownloadStatus downloadStatus = downloadService.gid2DownloadProgress[gallery.gid]!.downloadStatus;
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

  Widget _buildFooter(GalleryDownloadedData gallery) {
    return GetBuilder<GalleryDownloadService>(
      id: '$galleryDownloadProgressId::${gallery.gid}',
      builder: (_) {
        GalleryDownloadProgress downloadProgress = downloadService.gid2DownloadProgress[gallery.gid]!;
        GalleryDownloadSpeedComputer speedComputer = downloadService.gid2SpeedComputer[gallery.gid]!;
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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

  void _listen2AddItem(GetBuilderState<GalleryDownloadService> state) {
    downloadService.addListenerId(
      downloadGallerysId,
      () {
        if (downloadService.gallerys.length > gallerysCount) {
          _listKey.currentState?.insertItem(0);
        }
        gallerysCount = downloadService.gallerys.length;
      },
    );
  }

  void _handleRemoveItem(BuildContext context, int index) {
    downloadService.deleteGallery(downloadService.gallerys[index]);

    _listKey.currentState?.removeItem(
      index,
      (context, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          child: _removeItemBuilder(),
        ),
      ),
    );
  }

  void _showDeleteBottomSheet(GalleryDownloadedData gallery, int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              _handleRemoveItem(context, index);
              back();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => back(),
        ),
      ),
    );
  }

  void _goToReadPage(GalleryDownloadedData gallery) {
    int readIndexRecord = storageService.read('readIndexRecord::${gallery.gid}') ?? 0;

    toNamed(
      Routes.read,
      parameters: {
        'mode': 'local',
        'gid': gallery.gid.toString(),
        'initialIndex': readIndexRecord.toString(),
        'pageCount': gallery.pageCount.toString(),
        'galleryUrl': gallery.galleryUrl,
      },
    );
  }
}
