import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/local_gallery_body.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../service/gallery_download_service.dart';
import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'archive_download_body.dart';
import 'gallery_download_body.dart';

enum DownloadPageBodyType { download, archive, local }

class DownloadPage extends StatefulWidget {
  final bool showMenuButton;

  const DownloadPage({Key? key, this.showMenuButton = false}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final GalleryDownloadService downloadService = Get.find();

  DownloadPageBodyType bodyType = DownloadPageBodyType.download;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: CupertinoSlidingSegmentedControl<DownloadPageBodyType>(
          groupValue: bodyType,
          children: {
            DownloadPageBodyType.download: Text('download'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            DownloadPageBodyType.archive: Text('archive'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            DownloadPageBodyType.local: Text('local'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          },
          onValueChanged: (value) => setState(() {
            bodyType = value ?? bodyType;
          }),
        ),
        elevation: 1,
        leadingWidth: 70,
        leading: ExcludeFocus(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showMenuButton)
                IconButton(
                  icon: const Icon(FontAwesomeIcons.bars, size: 20),
                  onPressed: () => TapMenuButtonNotification().dispatch(context),
                ),
              if (bodyType == DownloadPageBodyType.local)
                IconButton(
                  icon: const Icon(Icons.help, size: 22),
                  onPressed: _showLocalGalleryHelpInfo,
                  visualDensity: const VisualDensity(horizontal: -4),
                ),
            ],
          ),
        ),
        actions: [
          if (bodyType == DownloadPageBodyType.download)
            ExcludeFocus(
              child: IconButton(
                icon: Icon(Icons.play_arrow, size: 26, color: Get.theme.primaryColor),
                onPressed: downloadService.resumeAllDownloadGallery,
                visualDensity: const VisualDensity(horizontal: -4),
              ),
            ),
          if (bodyType == DownloadPageBodyType.download)
            ExcludeFocus(
              child: IconButton(
                icon: Icon(Icons.pause, size: 26, color: Get.theme.primaryColorLight),
                onPressed: downloadService.pauseAllDownloadGallery,
              ),
            ),
          if (bodyType == DownloadPageBodyType.local)
            ExcludeFocus(
              child: IconButton(
                icon: Icon(Icons.refresh, size: 26, color: Get.theme.primaryColor),
                onPressed: handleRefreshLocalGallery,
              ),
            ),
        ],
      ),
      body: bodyType == DownloadPageBodyType.archive
          ? FadeIn(
              key: const Key('1'),
              child: const ArchiveDownloadBody(key: PageStorageKey('ArchiveDownloadBody')),
            )
          : bodyType == DownloadPageBodyType.download
              ? FadeIn(
                  key: const Key('2'),
                  child: const GalleryDownloadBody(key: PageStorageKey('GalleryDownloadBody')),
                )
              : FadeIn(
                  key: const Key('3'),
                  child: const LocalGalleryBody(key: PageStorageKey('LocalGalleryBody')),
                ),
    );
  }

  Future<void> handleRefreshLocalGallery() async {
    int addCount = await Get.find<LocalGalleryService>().refreshLocalGallerys();
    setState(() {});

    toast('${'newGalleryCount'.tr}: $addCount');
  }

  void _showLocalGalleryHelpInfo() {
    toast('localGalleryHelpInfo'.tr, isShort: false);
  }
}
