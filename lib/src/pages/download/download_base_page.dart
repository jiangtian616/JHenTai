import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/download/grid/gallery/gallery_category_grid_download_page.dart';
import 'package:jhentai/src/pages/download/grid/local/local_gallery_grid_page.dart';
import 'package:jhentai/src/pages/download/list/gallery/gallery_category_list_download_page.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';
import '../../config/ui_config.dart';
import 'grid/archive/archive_grid_download_page.dart';
import 'grid/gallery/gallery_grid_download_page.dart';
import 'list/archive/archive_list_download_page.dart';
import 'list/gallery/gallery_list_download_page.dart';
import 'list/local/local_gallery_list_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({Key? key}) : super(key: key);

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  DownloadPageGalleryType galleryType = DownloadPageGalleryType.download;
  DownloadPageBodyType bodyType = GetPlatform.isMobile
      ? DownloadPageBodyType.list
      : DownloadPageBodyType.grid;
  Completer<void> bodyTypeCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();

    localConfigService
        .read(configKey: ConfigEnum.downloadPageBodyType)
        .then((bodyTypeString) {
      if (bodyTypeString != null) {
        bodyType =
            DownloadPageBodyType.values[int.tryParse(bodyTypeString) ?? 0];
      }
    }).whenComplete(() {
      bodyTypeCompleter.complete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: NotificationListener<DownloadPageBodyTypeChangeNotification>(
        onNotification: (DownloadPageBodyTypeChangeNotification notification) {
          setState(() {
            galleryType = notification.galleryType ?? galleryType;
            bodyType = notification.bodyType ?? bodyType;
          });
          localConfigService.write(
              configKey: ConfigEnum.downloadPageBodyType,
              value: (notification.bodyType ?? bodyType).index.toString());
          return true;
        },
        child: FutureBuilder(
          future: bodyTypeCompleter.future,
          builder: (_, __) => !bodyTypeCompleter.isCompleted
              ? const Center()
              : _buildPageBody(),
        ),
      ),
    ).enableMouseDrag();
  }

  Widget _buildPageBody() {
    switch (galleryType) {
      case DownloadPageGalleryType.download:
        return bodyType == DownloadPageBodyType.list
            ? GalleryListDownloadPage(
                key: const PageStorageKey('GalleryListDownloadBody'))
            : GalleryGridDownloadPage(
                key: const PageStorageKey('GalleryGridDownloadBody'));
      case DownloadPageGalleryType.archive:
        return bodyType == DownloadPageBodyType.list
            ? ArchiveListDownloadPage(
                key: const PageStorageKey('ArchiveListDownloadBody'))
            : ArchiveGridDownloadPage(
                key: const PageStorageKey('ArchiveGridDownloadBody'));
      case DownloadPageGalleryType.local:
        return bodyType == DownloadPageBodyType.list
            ? LocalGalleryListPage(
                key: const PageStorageKey('LocalGalleryListBody'))
            : LocalGalleryGridPage(
                key: const PageStorageKey('LocalGalleryGridBody'));
      case DownloadPageGalleryType.downloadCategory:
        return bodyType == DownloadPageBodyType.list
            ? GalleryCategoryListDownloadPage(
                key: const PageStorageKey('GalleryCategoryListDownloadBody'))
            : GalleryCategoryGridDownloadPage(
                key: const PageStorageKey('GalleryCategoryGridDownloadBody'));
    }
  }
}

enum DownloadPageGalleryType { download, archive, local, downloadCategory }

enum DownloadPageBodyType { list, grid }

class DownloadPageBodyTypeChangeNotification extends Notification {
  DownloadPageGalleryType? galleryType;
  DownloadPageBodyType? bodyType;

  DownloadPageBodyTypeChangeNotification({this.galleryType, this.bodyType});
}

class DownloadPageSegmentControl extends StatelessWidget {
  final DownloadPageGalleryType galleryType;

  const DownloadPageSegmentControl({Key? key, required this.galleryType})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<DownloadPageGalleryType>(
      groupValue: galleryType,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      children: {
        DownloadPageGalleryType.download: _buildSegment('download'.tr),
        DownloadPageGalleryType.archive: _buildSegment('archive'.tr),
        DownloadPageGalleryType.local: _buildSegment('local'.tr),
        if (GetPlatform.isMacOS)
          DownloadPageGalleryType.downloadCategory:
              _buildSegment('downloadCategory'.tr, width: 72),
      },
      onValueChanged: (value) =>
          DownloadPageBodyTypeChangeNotification(galleryType: value!)
              .dispatch(context),
    );
  }

  Widget _buildSegment(String text,
      {double width = UIConfig.downloadPageSegmentedControlWidth}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
              fontSize: UIConfig.downloadPageSegmentedTextSize,
              fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class GroupOpenIndicator extends StatefulWidget {
  final bool isOpen;

  const GroupOpenIndicator({Key? key, required this.isOpen}) : super(key: key);

  @override
  State<GroupOpenIndicator> createState() => _GroupOpenIndicatorState();
}

class _GroupOpenIndicatorState extends State<GroupOpenIndicator>
    with AnimationMixin {
  bool isOpen = false;
  late Animation<double> animation =
      Tween<double>(begin: 0.0, end: -0.25).animate(controller);

  @override
  void initState() {
    super.initState();

    isOpen = widget.isOpen;
    if (isOpen) {
      controller.forward(from: 1);
    }
  }

  @override
  void didUpdateWidget(covariant GroupOpenIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOpen == widget.isOpen) {
      return;
    }

    isOpen = widget.isOpen;
    if (isOpen) {
      controller.play(duration: const Duration(milliseconds: 150));
    } else {
      controller.playReverse(duration: const Duration(milliseconds: 150));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: animation,
      child: const Icon(Icons.keyboard_arrow_left),
    );
  }
}
