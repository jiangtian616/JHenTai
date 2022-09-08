import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/local/local_gallery_page.dart';
import '../../config/ui_config.dart';
import 'archive/archive_download_page.dart';
import 'gallery/gallery_download_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  DownloadPageBodyType bodyType = DownloadPageBodyType.download;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: NotificationListener<DownloadPageBodyTypeChangeNotification>(
        onNotification: (DownloadPageBodyTypeChangeNotification notification) {
          setState(() => bodyType = notification.bodyType);
          return true;
        },
        child: bodyType == DownloadPageBodyType.archive
            ? ArchiveDownloadPage(key: const PageStorageKey('ArchiveDownloadBody'))
            : bodyType == DownloadPageBodyType.download
                ? GalleryDownloadPage(key: const PageStorageKey('GalleryDownloadBody'))
                : LocalGalleryPage(key: const PageStorageKey('LocalGalleryBody')),
      ),
    );
  }
}

enum DownloadPageBodyType { download, archive, local }

class DownloadPageBodyTypeChangeNotification extends Notification {
  final DownloadPageBodyType bodyType;

  DownloadPageBodyTypeChangeNotification(this.bodyType);
}

class EHDownloadPageSegmentControl extends StatelessWidget {
  final DownloadPageBodyType bodyType;

  const EHDownloadPageSegmentControl({Key? key, required this.bodyType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<DownloadPageBodyType>(
      groupValue: bodyType,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      children: {
        DownloadPageBodyType.download: SizedBox(
          width: UIConfig.downloadPageSegmentedControlWidth,
          child: Center(
            child: Text(
              'download'.tr,
              style: const TextStyle(fontSize: UIConfig.downloadPageSegmentedTextSize, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DownloadPageBodyType.archive: Text(
          'archive'.tr,
          style: const TextStyle(fontSize: UIConfig.downloadPageSegmentedTextSize, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        DownloadPageBodyType.local: Text(
          'local'.tr,
          style: const TextStyle(fontSize: UIConfig.downloadPageSegmentedTextSize, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      },
      onValueChanged: (value) => DownloadPageBodyTypeChangeNotification(value!).dispatch(context),
    );
  }
}
