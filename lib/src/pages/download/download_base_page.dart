import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/local/local_gallery_page.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';
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

class FadeShrinkWidget extends StatefulWidget {
  final bool show;
  final Widget child;
  final VoidCallback? afterDisappear;

  const FadeShrinkWidget({
    Key? key,
    required this.show,
    required this.child,
    this.afterDisappear,
  }) : super(key: key);

  @override
  State<FadeShrinkWidget> createState() => _FadeShrinkWidgetState();
}

class _FadeShrinkWidgetState extends State<FadeShrinkWidget> with AnimationMixin {
  bool show = false;

  late Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.ease);

  @override
  void initState() {
    super.initState();

    show = widget.show;
    if (show) {
      controller.forward(from: 1);
    }
  }

  @override
  void didUpdateWidget(covariant FadeShrinkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.show == widget.show) {
      return;
    }

    show = widget.show;
    if (show) {
      controller.play(duration: const Duration(milliseconds: 1000));
    } else {
      controller.playReverse(duration: const Duration(milliseconds: 1000)).then((_) {
        widget.afterDisappear?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: widget.child,
      ),
    );
  }
}

class GroupList<E, G> extends StatefulWidget {
  final List<G> groups;
  final List<E> elements;

  /// Defines which elements are grouped together.
  final G Function(E element) groupBy;

  final Widget Function(G group) groupBuilder;
  final Widget Function(BuildContext context, E element) itemBuilder;

  const GroupList({
    Key? key,
    required this.groups,
    required this.elements,
    required this.groupBy,
    required this.groupBuilder,
    required this.itemBuilder,
  }) : super(key: key);

  @override
  State<GroupList> createState() => _GroupListState();
}

class _GroupListState<E, G> extends State<GroupList<E, G>> {
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    assert(widget.groups.every((g) => widget.elements.singleWhereOrNull((e) => widget.groupBy(e) == g) != null));
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.elements.length + widget.groups.length,
      itemBuilder: (BuildContext context, int index) {
        int remainingCount = index;
        int groupIndex = 0;

        while (true) {
          G group = widget.groups[groupIndex];
          List<E> itemsWithGroup = widget.elements.where((element) => widget.groupBy(element) == group).toList();

          if (remainingCount == 0) {
            return widget.groupBuilder(group);
          }

          if (remainingCount - itemsWithGroup.length <= 0) {
            return widget.itemBuilder(context, itemsWithGroup[remainingCount - 1]);
          }

          groupIndex++;
          remainingCount -= 1 + itemsWithGroup.length;
        }
      },
    );
  }
}
