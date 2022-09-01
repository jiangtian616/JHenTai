import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/download/local/local_gallery_page.dart';
import 'archive/archive_download_page.dart';
import 'gallery/gallery_download_page.dart';

class DownloadPage extends StatefulWidget {
  final bool showMenuButton;

  const DownloadPage({Key? key, this.showMenuButton = false}) : super(key: key);

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
            ? ArchiveDownloadPage(key: const PageStorageKey('ArchiveDownloadBody'), showMenuButton: widget.showMenuButton)
            : bodyType == DownloadPageBodyType.download
                ? GalleryDownloadPage(key: const PageStorageKey('GalleryDownloadBody'), showMenuButton: widget.showMenuButton)
                : LocalGalleryPage(key: const PageStorageKey('LocalGalleryBody'), showMenuButton: widget.showMenuButton),
      ),
    );
  }
}

enum DownloadPageBodyType { download, archive, local }

class DownloadPageBodyTypeChangeNotification extends Notification {
  final DownloadPageBodyType bodyType;

  DownloadPageBodyTypeChangeNotification(this.bodyType);
}
