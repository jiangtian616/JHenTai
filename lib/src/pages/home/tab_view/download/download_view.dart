import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/download/archive_download_body.dart';
import 'package:jhentai/src/pages/home/tab_view/download/gallery_download_body.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../service/gallery_download_service.dart';

class DownloadView extends StatefulWidget {
  const DownloadView({Key? key}) : super(key: key);

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  final GalleryDownloadService downloadService = Get.find();

  bool _showArchiveBody = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _showArchiveBody ? Text('archive'.tr) : Text('download'.tr),
        elevation: 1,
        leading: IconButton(
          onPressed: _showHelpInfo,
          icon: const Icon(Icons.help, size: 22),
        ),
        actions: [
          if (!_showArchiveBody)
            IconButton(
              onPressed: downloadService.resumeAllDownloadGallery,
              icon: Icon(Icons.play_arrow, size: 26, color: Get.theme.primaryColor),
            ),
          if (!_showArchiveBody)
            IconButton(
              onPressed: downloadService.pauseAllDownloadGallery,
              icon: Icon(Icons.pause, size: 26, color: Get.theme.primaryColorLight),
            ),
          IconButton(
            key: const Key('1'),
            onPressed: () => setState(() {
              _showArchiveBody = !_showArchiveBody;
            }),
            icon: _showArchiveBody ? const Icon(Icons.switch_left) : const Icon(Icons.switch_right),
          )
        ],
      ),
      body: _showArchiveBody
          ? FadeIn(
              key: const Key('1'),
              child: const ArchiveDownloadBody(
                key: PageStorageKey('ArchiveDownloadBody'),
              ),
            )
          : FadeIn(
              key: const Key('2'),
              child: const GalleryDownloadBody(
                key: PageStorageKey('GalleryDownloadBody'),
              ),
            ),
    );
  }

  void _showHelpInfo() {
    toast('downloadHelpInfo'.tr, isCenter: false, isShort: false);
  }
}
