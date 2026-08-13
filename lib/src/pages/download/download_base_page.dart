import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/download/grid/local/local_gallery_grid_page.dart';
import 'package:jhentai/src/pages/setting/network/lan/lan_gallery_list_page.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
  DownloadPageGalleryType galleryType = preferenceSetting.defaultDownloadTab.value;
  DownloadPageBodyType bodyType = GetPlatform.isMobile ? DownloadPageBodyType.list : DownloadPageBodyType.grid;
  Completer<void> bodyTypeCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();

    localConfigService.read(configKey: ConfigEnum.downloadPageBodyType).then((bodyTypeString) {
      if (bodyTypeString != null) {
        bodyType = DownloadPageBodyType.values[int.tryParse(bodyTypeString) ?? 0];
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
          localConfigService.write(configKey: ConfigEnum.downloadPageBodyType, value: (notification.bodyType ?? bodyType).index.toString());
          return true;
        },
        child: FutureBuilder(
          future: bodyTypeCompleter.future,
          builder: (_, __) => !bodyTypeCompleter.isCompleted
              ? const Center()
              : galleryType == DownloadPageGalleryType.download
                  ? bodyType == DownloadPageBodyType.list
                      ? GalleryListDownloadPage(key: const PageStorageKey('GalleryListDownloadBody'))
                      : GalleryGridDownloadPage(key: const PageStorageKey('GalleryGridDownloadBody'))
                  : galleryType == DownloadPageGalleryType.archive
                      ? bodyType == DownloadPageBodyType.list
                          ? ArchiveListDownloadPage(key: const PageStorageKey('ArchiveListDownloadBody'))
                          : ArchiveGridDownloadPage(key: const PageStorageKey('ArchiveGridDownloadBody'))
                      : Obx(
                          () => advancedSetting.lanLocalTabAsLan.value
                              ? const LanGalleryListPage(
                                  key: PageStorageKey('LanGalleryListBody'),
                                )
                              : bodyType == DownloadPageBodyType.list
                                  ? LocalGalleryListPage(
                                      key: const PageStorageKey(
                                        'LocalGalleryListBody',
                                      ),
                                    )
                                  : LocalGalleryGridPage(
                                      key: const PageStorageKey(
                                        'LocalGalleryGridBody',
                                      ),
                                    ),
                        ),
        ),
      ),
    ).enableMouseDrag();
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
    const TextStyle segmentTextStyle = TextStyle(
      fontSize: UIConfig.downloadPageSegmentedTextSize,
      fontWeight: FontWeight.bold,
    );
    return ThemeConfig.isApple
        ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Keep the segmented control compact so the AppBar centers it
                // instead of clamping a full-width control against the trailing
                // actions (which pushes it to the right).
                maxWidth: DownloadPageGalleryType.values.length *
                        UIConfig.downloadPageSegmentedControlWidth +
                    40,
              ),
              child: GlassSegmentedControl(
                selectedIndex: galleryType.index,
                segments: [
                  for (final type in DownloadPageGalleryType.values)
                    GlassSegment(label: type.name.tr),
                ],
                selectedTextStyle: segmentTextStyle,
                unselectedTextStyle: segmentTextStyle,
                onSegmentSelected: (index) =>
                    DownloadPageBodyTypeChangeNotification(
                      galleryType: DownloadPageGalleryType.values[index],
                    ).dispatch(context),
              ),
            ),
          )
        : CupertinoSlidingSegmentedControl<DownloadPageGalleryType>(
            groupValue: galleryType,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
            children: {
              DownloadPageGalleryType.download: SizedBox(
                width: UIConfig.downloadPageSegmentedControlWidth,
                child: Center(
                  child: Text(
                    'download'.tr,
                    style: segmentTextStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DownloadPageGalleryType.archive: Text(
                'archive'.tr,
                style: segmentTextStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              DownloadPageGalleryType.local: Text(
                'local'.tr,
                style: segmentTextStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            },
            onValueChanged: (value) =>
                DownloadPageBodyTypeChangeNotification(galleryType: value!)
                    .dispatch(context),
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
    final Widget chevron = RotationTransition(
      turns: animation,
      child: const Icon(Icons.keyboard_arrow_left),
    );
    if (ThemeConfig.isApple) {
      // Passive glass circle indicator — must not absorb the row's tap.
      return GlassContainer(
        shape: const LiquidOval(),
        width: 28,
        height: 28,
        child: chevron,
      );
    }
    return chevron;
  }
}
