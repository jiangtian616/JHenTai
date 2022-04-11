import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/download_service.dart';

import '../../../../model/download_progress.dart';
import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../service/storage_service.dart';
import '../../../../utils/date_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/eh_gallery_category_tag.dart';

class DownloadView extends StatelessWidget {
  final DownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late int galleryLength = downloadService.gallerys.length;

  DownloadView({Key? key}) : super(key: key) {
    /// manually handle add or delete item
    ever<List<GalleryDownloadedData>>(
      downloadService.gallerys,
      (gallerys) {
        if (gallerys.length > galleryLength) {
          _listKey.currentState?.insertItem(0);
        }
        galleryLength = gallerys.length;
      },
      condition: () => downloadService.gallerys.length != galleryLength,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('download'.tr),
        elevation: 1,
      ),
      body: AnimatedList(
        key: _listKey,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        initialItemCount: galleryLength,
        itemBuilder: (context, index, animation) => _itemBuilder(context, index),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    GalleryDownloadedData gallery = downloadService.gallerys[index];
    return Slidable(
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
    );
  }

  Widget _buildCover(GalleryDownloadedData gallery, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toNamed(Routes.details, arguments: gallery.galleryUrl),
      child: Obx(
        () {
          GalleryImage? image = downloadService.gid2Images[gallery.gid]![0].value;

          /// cover is the first image, if we haven't downloaded first image, then return a [CupertinoActivityIndicator]
          if (image == null ||
              image.downloadStatus != DownloadStatus.downloading && image.downloadStatus != DownloadStatus.downloaded) {
            return const SizedBox(
              height: 130,
              width: 110,
              child: CupertinoActivityIndicator(),
            );
          }

          return EHImage(
            containerHeight: 130,
            containerWidth: 110,
            galleryImage: image,
            adaptive: true,
            fit: BoxFit.cover,
          );
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
            Obx(() {
              DownloadStatus downloadStatus = downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus;
              return GestureDetector(
                onTap: () {
                  downloadStatus == DownloadStatus.paused
                      ? downloadService.downloadGallery(gallery, isFirstDownload: false)
                      : downloadService.pauseDownloadGallery(gallery);
                },
                child: Icon(
                  downloadStatus == DownloadStatus.paused
                      ? Icons.play_arrow
                      : downloadStatus == DownloadStatus.downloading
                          ? Icons.pause
                          : Icons.done,
                  size: 26,
                  color: downloadStatus == DownloadStatus.downloading
                      ? Get.theme.primaryColorLight
                      : Get.theme.primaryColor,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(GalleryDownloadedData gallery) {
    return Obx(() {
      DownloadProgress downloadProgress = downloadService.gid2downloadProgress[gallery.gid]!.value;
      SpeedComputer speedComputer = downloadService.gid2SpeedComputer[gallery.gid]!;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (downloadProgress.downloadStatus != DownloadStatus.downloaded)
                Text(
                  speedComputer.speed.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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
                color: downloadProgress.downloadStatus == DownloadStatus.downloading
                    ? Get.theme.primaryColorLight
                    : Get.theme.primaryColor,
              ),
            ).marginOnly(top: 4),
        ],
      );
    });
  }

  /// remove Obx() in removedItem
  Widget _removedItemBuilder(
    BuildContext context,
    GalleryDownloadedData gallery,
    GalleryImage? image,
    DownloadStatus downloadStatus,
    DownloadProgress downloadProgress,
    SpeedComputer speedComputer,
  ) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            _buildRemovedCover(image),
            _buildRemovedInfo(gallery, downloadStatus, downloadProgress, speedComputer),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedCover(GalleryImage? image) {
    if (image == null ||
        image.downloadStatus != DownloadStatus.downloading && image.downloadStatus != DownloadStatus.downloaded) {
      return const SizedBox(
        height: 130,
        width: 110,
        child: CupertinoActivityIndicator(),
      );
    }

    return EHImage(
      containerHeight: 130,
      containerWidth: 110,
      galleryImage: image,
      adaptive: true,
      fit: BoxFit.cover,
    );
  }

  Widget _buildRemovedInfo(GalleryDownloadedData gallery, DownloadStatus downloadStatus,
      DownloadProgress downloadProgress, SpeedComputer speedComputer) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(gallery),
          const Expanded(child: SizedBox()),
          _buildRemovedCenter(gallery, downloadStatus),
          _buildRemovedFooter(
            gallery,
            downloadProgress,
            speedComputer,
          ).marginOnly(top: 4),
        ],
      ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
    );
  }

  Widget _buildRemovedCenter(GalleryDownloadedData gallery, DownloadStatus downloadStatus) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            Icon(
              downloadStatus == DownloadStatus.paused
                  ? Icons.play_arrow
                  : downloadStatus == DownloadStatus.downloading
                      ? Icons.pause
                      : Icons.done,
              size: 26,
              color:
                  downloadStatus == DownloadStatus.downloading ? Get.theme.primaryColorLight : Get.theme.primaryColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemovedFooter(
      GalleryDownloadedData gallery, DownloadProgress downloadProgress, SpeedComputer speedComputer) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (downloadProgress.downloadStatus != DownloadStatus.downloaded)
              Text(
                speedComputer.speed.value,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
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
              color: downloadProgress.downloadStatus == DownloadStatus.downloading
                  ? Get.theme.primaryColorLight
                  : Get.theme.primaryColor,
            ),
          ).marginOnly(top: 4),
      ],
    );
  }

  void _handleRemoveItem(BuildContext context, int index) {
    GalleryDownloadedData gallery = downloadService.gallerys[index];
    GalleryImage? image = downloadService.gid2Images[gallery.gid]![0].value;
    DownloadStatus downloadStatus = downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus;
    DownloadProgress downloadProgress = downloadService.gid2downloadProgress[gallery.gid]!.value;
    SpeedComputer speedComputer = downloadService.gid2SpeedComputer[gallery.gid]!;

    downloadService.deleteGallery(gallery);

    _listKey.currentState?.removeItem(
      index,
      (context, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          child: _removedItemBuilder(context, gallery, image, downloadStatus, downloadProgress, speedComputer),
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
      arguments: gallery,
      parameters: {
        'type': 'local',
        'gid': gallery.gid.toString(),
        'initialIndex': readIndexRecord.toString(),
        'pageCount': gallery.pageCount.toString(),
        'galleryUrl': gallery.galleryUrl,
      },
    );
  }
}
