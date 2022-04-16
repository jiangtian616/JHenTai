import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_archive.dart';
import 'package:jhentai/src/service/archive_download_service.dart';

import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../service/storage_service.dart';
import '../../../../utils/byte_util.dart';
import '../../../../utils/date_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/speed_computer.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/eh_gallery_category_tag.dart';

class ArchiveDownloadBody extends StatefulWidget {
  const ArchiveDownloadBody({Key? key}) : super(key: key);

  @override
  State<ArchiveDownloadBody> createState() => _ArchiveDownloadBodyState();
}

class _ArchiveDownloadBodyState extends State<ArchiveDownloadBody> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final ArchiveDownloadService archiveDownloadService = Get.find();
  final StorageService storageService = Get.find();

  late int archivesCount;

  @override
  void initState() {
    archivesCount = archiveDownloadService.archives.length;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ArchiveDownloadService>(
      initState: _listen2AddItem,
      builder: (_) {
        return AnimatedList(
          key: _listKey,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          initialItemCount: archivesCount,
          itemBuilder: (context, index, animation) => _itemBuilder(context, index),
        );
      },
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    ArchiveDownloadedData archive = archiveDownloadService.archives[index];
    return Slidable(
      key: Key(archive.gid.toString()),
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
        onLongPress: () => _showDeleteBottomSheet(archive, index, context),
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
                _buildCover(archive, context),
                _buildInfo(archive),
              ],
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

  Widget _buildCover(ArchiveDownloadedData archive, BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toNamed(Routes.details, arguments: archive.galleryUrl),
      child: EHImage.network(
        containerHeight: 130,
        containerWidth: 110,
        galleryImage: GalleryImage(
          url: archive.coverUrl,
          width: archive.coverWidth,
          height: archive.coverHeight,
        ),
        adaptive: true,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildInfo(ArchiveDownloadedData archive) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goToReadPage(archive),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(archive),
            _buildCenter(archive),
            _buildFooter(archive),
          ],
        ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
      ),
    );
  }

  Widget _buildHeader(ArchiveDownloadedData archive) {
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ).marginOnly(top: 5),
            Text(
              DateUtil.transform2LocalTimeString(archive.publishTime),
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

  Widget _buildCenter(ArchiveDownloadedData archive) {
    return Row(
      children: [EHGalleryCategoryTag(category: archive.category)],
    );
  }

  Widget _buildFooter(ArchiveDownloadedData archive) {
    return GetBuilder<ArchiveDownloadService>(
      id: '$archiveStatusId::${archive.gid}::${archive.isOriginal}',
      builder: (_) {
        ArchiveStatus archiveStatus = archiveDownloadService.archiveStatuses.get(archive.gid, archive.isOriginal)!;
        SpeedComputer speedComputer = archiveDownloadService.speedComputers.get(archive.gid, archive.isOriginal)!;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (archiveStatus == ArchiveStatus.downloading)
                  GetBuilder<ArchiveDownloadService>(
                    id: '$speedComputerId::${archive.gid}::${archive.isOriginal}',
                    builder: (logic) {
                      return Text(
                        speedComputer.speed,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      );
                    },
                  ),
                const Expanded(child: SizedBox()),
                if (archiveStatus == ArchiveStatus.downloading)
                  GetBuilder<ArchiveDownloadService>(
                    id: '$speedComputerId::${archive.gid}::${archive.isOriginal}',
                    builder: (logic) {
                      return Text(
                        '${byte2String(speedComputer.downloadedBytes.toDouble())}/${byte2String(archive.size.toDouble())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  ),
                if (archiveStatus != ArchiveStatus.downloading)
                  Text(
                    archiveStatus.name.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            if (archiveStatus.index < ArchiveStatus.downloaded.index)
              SizedBox(
                height: 3,
                child: GetBuilder<ArchiveDownloadService>(
                  id: '$speedComputerId::${archive.gid}::${archive.isOriginal}',
                  builder: (logic) {
                    return LinearProgressIndicator(
                      value: speedComputer.downloadedBytes / archive.size,
                      color:
                          archiveStatus == ArchiveStatus.paused ? Get.theme.primaryColor : Get.theme.primaryColorLight,
                    );
                  },
                ),
              ).marginOnly(top: 4),
          ],
        );
      },
    );
  }

  void _listen2AddItem(GetBuilderState<ArchiveDownloadService> state) {
    archiveDownloadService.addListenerId(
      downloadArchivesId,
      () {
        if (archiveDownloadService.archives.length > archivesCount) {
          _listKey.currentState?.insertItem(0);
        }
        archivesCount = archiveDownloadService.archives.length;
      },
    );
  }

  void _handleRemoveItem(BuildContext context, int index) {
    archiveDownloadService.deleteArchive(archiveDownloadService.archives[index]);

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

  void _showDeleteBottomSheet(ArchiveDownloadedData archive, int index, BuildContext context) {
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

  void _goToReadPage(ArchiveDownloadedData archive) {
    if (archiveDownloadService.archiveStatuses.get(archive.gid, archive.isOriginal) != ArchiveStatus.completed) {
      return;
    }

    List<GalleryImage> images = archiveDownloadService.getUnpackedImages(archive);
    int readIndexRecord = storageService.read('readIndexRecord::${archive.gid}') ?? 0;

    toNamed(
      Routes.read,
      arguments: images,
      parameters: {
        'mode': 'local',
        'gid': archive.gid.toString(),
        'initialIndex': readIndexRecord.toString(),
        'pageCount': archive.pageCount.toString(),
        'galleryUrl': archive.galleryUrl,
      },
    );
  }
}
