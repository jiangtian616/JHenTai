import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/download/archive_download_body.dart';
import 'package:jhentai/src/pages/home/tab_view/download/gallery_download_body.dart';

class DownloadView extends StatefulWidget {
  const DownloadView({Key? key}) : super(key: key);

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  bool showArchiveBody = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: showArchiveBody ? Text('archive'.tr) : Text('gallery'.tr),
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () => setState(() {
              showArchiveBody = !showArchiveBody;
            }),
            icon: showArchiveBody ? const Icon(Icons.switch_left) : const Icon(Icons.switch_right),
          )
        ],
      ),
      body: showArchiveBody
          ? FadeIn(key: const Key('1'), child: const ArchiveDownloadBody())
          : FadeIn(child: const GalleryDownloadBody()),
    );
  }
}
