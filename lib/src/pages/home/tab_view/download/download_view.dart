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

  DownloadView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('download'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: downloadService.gallerys
              .map((gallery) => Slidable(
                    key: Key(gallery.gid.toString()),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.15,
                      children: [
                        SlidableAction(
                          icon: Icons.delete,
                          foregroundColor: Colors.red,
                          backgroundColor: Get.theme.scaffoldBackgroundColor,
                          onPressed: (BuildContext context) => downloadService.deleteGallery(gallery),
                        )
                      ],
                    ),
                    child: GestureDetector(
                      onLongPress: () => _showDeleteBottomSheet(gallery, context),
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
                  ))
              .toList(),
        );
      }),
    );
  }

  Widget _buildCover(GalleryDownloadedData gallery, BuildContext context) {
    Widget child;
    GalleryImage? image = downloadService.gid2Images[gallery.gid]![0].value;

    /// cover is the first image, if we haven't downloaded first image, then return a [CupertinoActivityIndicator]
    if (image == null) {
      child = const SizedBox(
        height: 130,
        width: 110,
        child: CupertinoActivityIndicator(),
      );
    } else {
      child = EHImage(
        containerHeight: 130,
        containerWidth: 110,
        galleryImage: image,
        adaptive: true,
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toNamed(Routes.details, arguments: gallery.galleryUrl),
      child: child,
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
    DownloadStatus downloadStatus = downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            GestureDetector(
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(GalleryDownloadedData gallery) {
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
  }

  void _showDeleteBottomSheet(GalleryDownloadedData gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              downloadService.deleteGallery(gallery);
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
