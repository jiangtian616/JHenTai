import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_archive.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../network/eh_request.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';

class ArchiveDialog extends StatefulWidget {
  const ArchiveDialog({Key? key}) : super(key: key);

  @override
  _ArchiveDialogState createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<ArchiveDialog> {
  final DetailsPageLogic logic = DetailsPageLogic.current!;
  final DetailsPageState state = DetailsPageLogic.current!.state;
  final ArchiveDownloadService archiveDownloadService = Get.find();

  LoadingState loadingState = LoadingState.idle;
  late GalleryArchive archive;

  @override
  void initState() {
    _getArchiveInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('archive'.tr)),
      children: [
        LoadingStateIndicator(
          loadingState: loadingState,
          errorTapCallback: _getArchiveInfo,
          successWidgetBuilder: () => Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: Get.theme.primaryColor,
                    child: const Center(
                      child: Text(
                        'C',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Text(archive.creditCount.toString()).marginOnly(left: 2),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        archive.originalCost == 0 ? 'Free!' : '${archive.originalCost} C',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      ElevatedButton(
                        onPressed: archive.originalCost > archive.creditCount ? null : () => _downloadArchive(true),
                        child: Row(
                          children: [
                            const Text('Original'),
                            const Icon(Icons.download_for_offline, size: 18).marginOnly(left: 2),
                          ],
                        ).marginSymmetric(horizontal: 8),
                      ),
                      Text(archive.originalSize, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  Column(
                    children: [
                      if (archive.resampleCost != null)
                        Text(
                          archive.resampleCost == 0 ? 'Free!' : '${archive.resampleCost} C',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ElevatedButton(
                        onPressed: archive.resampleCost == null || archive.resampleCost! > archive.creditCount
                            ? null
                            : () => _downloadArchive(false),
                        child: Row(
                          children: [
                            const Text('Resample'),
                            const Icon(Icons.download_for_offline, size: 18).marginOnly(left: 2),
                          ],
                        ),
                      ),
                      if (archive.resampleCost != null)
                        Text(archive.resampleSize!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )
                ],
              ).marginOnly(top: 18),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _getArchiveInfo() async {
    setState(() {
      loadingState = LoadingState.loading;
    });

    try {
      archive = await EHRequest.request(
        url: state.galleryDetails!.archivePageUrl,
        parser: EHSpiderParser.archivePage2Archive,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      Log.error('getGalleryArchiveFailed'.tr, e.message);
      snack('getGalleryArchiveFailed'.tr, e.message, snackPosition: SnackPosition.TOP);
      setState(() {
        loadingState = LoadingState.error;
      });
      return;
    }

    setState(() {
      loadingState = LoadingState.success;
    });
  }

  void _downloadArchive(bool isOriginal) {
    archiveDownloadService.downloadArchive(
      state.gallery!.toArchiveDownloadedData(
        state.galleryDetails!.archivePageUrl,
        isOriginal,
        _computeSizeInBytes(isOriginal),
      ),
    );
    snack('beginToDownloadArchive'.tr, 'beginToDownloadArchiveHint'.tr);
  }

  int _computeSizeInBytes(bool isOriginal) {
    String sizeString = isOriginal ? archive.originalSize : archive.resampleSize!;

    List<String> parts = sizeString.split(' ');
    double number = double.parse(parts[0]);
    String unit = parts[1];

    if (unit.startsWith('K')) {
      return (number * 1024).toInt();
    }
    if (unit.startsWith('M')) {
      return (number * 1024 * 1024).toInt();
    }
    return (number * 1024 * 1024 * 1024).toInt();
  }
}
