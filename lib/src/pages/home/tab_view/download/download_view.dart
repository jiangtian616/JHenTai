import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/download_service.dart';

import '../../../../config/global_config.dart';
import '../../../../consts/color_consts.dart';
import '../../../../consts/locale_consts.dart';
import '../../../../model/download_progress.dart';
import '../../../../model/gallery.dart';
import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/date_util.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/gallery_category_tag.dart';

class DownloadView extends StatelessWidget {
  final DownloadService downloadService = Get.find();

  DownloadView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('download'.tr),
        toolbarHeight: GlobalConfig.appBarHeight,
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),

          /// must assign controller
          controller: ScrollController(),
          children: downloadService.gallerys
              .map(
                (gallery) => GestureDetector(
                  onLongPress: () => _showDeleteBottomSheet(gallery, context),
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,

                      /// covered when in dark mode
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                          offset: const Offset(0.5, 3),
                        )
                      ],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.only(top: 5, bottom: 4, left: 10, right: 10),
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
              )
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
      onTap: () => Get.toNamed(Routes.details, arguments: gallery),
      child: child,
    );
  }

  Widget _buildInfo(GalleryDownloadedData gallery) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Get.toNamed(
            Routes.read,
            arguments: gallery,
            parameters: {
              'type': 'local',
              'gid': gallery.gid.toString(),
              'initialIndex': '0',
              'pageCount': gallery.pageCount.toString(),
              'galleryUrl': gallery.galleryUrl,
            },
          );
        },
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
            Text(
              gallery.uploader,
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
            GalleryCategoryTag(category: gallery.category),
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
                color: Get.theme.primaryColorLight,
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
              color: Get.theme.primaryColorLight,
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
            child: Text('delete'.tr),
            onPressed: () {
              downloadService.deleteGallery(gallery);
              Get.back();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: Get.back,
        ),
      ),
    );
  }
}
