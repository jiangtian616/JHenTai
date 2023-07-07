import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/grid/local/local_gallery_grid_page.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
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
  final StorageService storageService = Get.find<StorageService>();

  DownloadPageGalleryType galleryType = DownloadPageGalleryType.download;
  DownloadPageBodyType bodyType = GetPlatform.isMobile ? DownloadPageBodyType.list : DownloadPageBodyType.grid;

  @override
  void initState() {
    super.initState();
    bodyType = DownloadPageBodyType.values[storageService.read('downloadPageGalleryType') ?? 0];
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
          storageService.write('downloadPageGalleryType', (notification.bodyType ?? bodyType).index);
          return true;
        },
        child: galleryType == DownloadPageGalleryType.download
            ? bodyType == DownloadPageBodyType.list
                ? GalleryListDownloadPage(key: const PageStorageKey('GalleryListDownloadBody'))
                : GalleryGridDownloadPage(key: const PageStorageKey('GalleryGridDownloadBody'))
            : galleryType == DownloadPageGalleryType.archive
                ? bodyType == DownloadPageBodyType.list
                    ? ArchiveListDownloadPage(key: const PageStorageKey('ArchiveListDownloadBody'))
                    : ArchiveGridDownloadPage(key: const PageStorageKey('ArchiveGridDownloadBody'))
                : bodyType == DownloadPageBodyType.list
                    ? LocalGalleryListPage(key: const PageStorageKey('LocalGalleryListBody'))
                    : LocalGalleryGridPage(key: const PageStorageKey('LocalGalleryGridBody')),
      ),
    );
  }
}

enum DownloadPageGalleryType { download, archive, local }

enum DownloadPageBodyType { list, grid }

class DownloadPageBodyTypeChangeNotification extends Notification {
  DownloadPageGalleryType? galleryType;
  DownloadPageBodyType? bodyType;

  DownloadPageBodyTypeChangeNotification({this.galleryType, this.bodyType});
}

class DownloadPageSegmentControl extends StatelessWidget {
  final DownloadPageGalleryType galleryType;

  const DownloadPageSegmentControl({Key? key, required this.galleryType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<DownloadPageGalleryType>(
      groupValue: galleryType,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
      children: {
        DownloadPageGalleryType.download: SizedBox(
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
        DownloadPageGalleryType.archive: Text(
          'archive'.tr,
          style: const TextStyle(fontSize: UIConfig.downloadPageSegmentedTextSize, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        DownloadPageGalleryType.local: Text(
          'local'.tr,
          style: const TextStyle(fontSize: UIConfig.downloadPageSegmentedTextSize, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      },
      onValueChanged: (value) => DownloadPageBodyTypeChangeNotification(galleryType: value!).dispatch(context),
    );
  }
}

class GroupOpenIndicator extends StatefulWidget {
  final bool isOpen;

  const GroupOpenIndicator({Key? key, required this.isOpen}) : super(key: key);

  @override
  State<GroupOpenIndicator> createState() => _GroupOpenIndicatorState();
}

class _GroupOpenIndicatorState extends State<GroupOpenIndicator> with AnimationMixin {
  bool isOpen = false;
  late Animation<double> animation = Tween<double>(begin: 0.0, end: -0.25).animate(controller);

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

class GroupList<E, G> extends StatefulWidget {
  final List<G> groups;
  final List<E> elements;

  /// Defines which elements are grouped together.
  final G Function(E element) groupBy;

  final Widget Function(BuildContext context, G group) groupBuilder;
  final Widget Function(BuildContext context, E element) itemBuilder;

  final ScrollController? scrollController;

  const GroupList({
    Key? key,
    required this.groups,
    required this.elements,
    required this.groupBy,
    required this.groupBuilder,
    required this.itemBuilder,
    this.scrollController,
  }) : super(key: key);

  @override
  State<GroupList<E, G>> createState() => _GroupListState<E, G>();
}

class _GroupListState<E, G> extends State<GroupList<E, G>> {
  bool useInnerController = false;
  late ScrollController scrollController;

  @override
  void initState() {
    assert(widget.elements.every((element) => widget.groups.contains(widget.groupBy(element))));
    super.initState();

    if (widget.scrollController == null) {
      scrollController = ScrollController();
      useInnerController = true;
    }
    scrollController = widget.scrollController!;
  }

  @override
  void dispose() {
    super.dispose();
    if (useInnerController) {
      scrollController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: widget.elements.length + widget.groups.length,
        cacheExtent: 6000,
        itemBuilder: (BuildContext context, int index) {
          int remainingCount = index;
          int groupIndex = 0;

          while (true) {
            G group = widget.groups[groupIndex];
            List<E> itemsWithGroup = widget.elements.where((E element) => widget.groupBy.call(element) == group).toList();

            if (remainingCount == 0) {
              return widget.groupBuilder(context, group);
            }

            if (remainingCount - itemsWithGroup.length <= 0) {
              return widget.itemBuilder(context, itemsWithGroup[remainingCount - 1]);
            }

            groupIndex++;
            remainingCount -= 1 + itemsWithGroup.length;
          }
        },
      ),
    );
  }
}
