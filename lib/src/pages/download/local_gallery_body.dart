import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';

import '../../model/read_page_info.dart';
import '../../routes/routes.dart';
import '../../service/storage_service.dart';
import '../../setting/style_setting.dart';
import '../../utils/route_util.dart';
import '../../widget/eh_image.dart';
import '../../widget/eh_wheel_speed_controller.dart';
import '../../widget/focus_widget.dart';
import '../layout/desktop/desktop_layout_page_logic.dart';

class LocalGalleryBody extends StatefulWidget {
  const LocalGalleryBody({Key? key}) : super(key: key);

  @override
  State<LocalGalleryBody> createState() => _LocalGalleryBodyState();
}

class _LocalGalleryBodyState extends State<LocalGalleryBody> with TickerProviderStateMixin {
  final LocalGalleryService localGalleryService = Get.find<LocalGalleryService>();
  final StorageService storageService = Get.find<StorageService>();

  final ScrollController _scrollController = ScrollController();

  final Map<String, AnimationController> removedTitle2AnimationController = {};
  final Map<String, Animation<double>> removedTitle2Animation = {};

  @override
  void initState() {
    if (Get.isRegistered<DesktopLayoutPageLogic>()) {
      Get.find<DesktopLayoutPageLogic>().state.scrollControllers[7] = _scrollController;
    }
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (AnimationController controller in removedTitle2AnimationController.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalGalleryService>(
      id: LocalGalleryService.refreshId,
      builder: (_) => EHWheelSpeedController(
        scrollController: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemCount: localGalleryService.gallerys.length,
          itemBuilder: (context, index) => _itemBuilder(context, index),
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    LocalGallery gallery = localGalleryService.gallerys[index];

    Widget child = FocusWidget(
      focusedDecoration: BoxDecoration(border: Border(right: BorderSide(width: 3, color: Theme.of(context).appBarTheme.foregroundColor!))),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => _goToReadPage(gallery),
      handleTapArrowRight: () => _goToReadPage(gallery),
      child: Slidable(
        key: Key(gallery.title),
        endActionPane: _buildEndActionPane(gallery),
        child: GestureDetector(
          onSecondaryTap: () => _showBottomSheet(gallery, index, context),
          onLongPress: () => _showBottomSheet(gallery, index, context),
          child: _buildCard(gallery),
        ),
      ),
    );

    /// has not been deleted
    if (!removedTitle2AnimationController.containsKey(gallery.title)) {
      return child;
    }

    AnimationController controller = removedTitle2AnimationController[gallery.title]!;
    Animation<double> animation = removedTitle2Animation[gallery.title]!;

    /// has been deleted, start animation
    if (!controller.isAnimating) {
      controller.forward();
    }

    return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child));
  }

  ActionPane _buildEndActionPane(LocalGallery gallery) {
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.3,
      children: [
        SlidableAction(
          icon: Icons.delete,
          foregroundColor: Colors.red,
          backgroundColor: Get.theme.scaffoldBackgroundColor,
          onPressed: (BuildContext context) => _handleRemoveItem(context, gallery),
        )
      ],
    );
  }

  Widget _buildCard(LocalGallery gallery) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _goToReadPage(gallery),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,

          /// covered when in dark mode
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              spreadRadius: 1,
              offset: const Offset(0.3, 1),
            )
          ],
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.only(top: 5, bottom: 5, left: 5, right: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Row(
            children: [
              _buildCover(gallery, context),
              _buildInfo(gallery),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(LocalGallery gallery, BuildContext context) {
    return Obx(
      () => EHImage.file(
        containerHeight: 130,
        containerWidth: 110,
        galleryImage: gallery.images[0],
        adaptive: true,
        fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
      ),
    );
  }

  Widget _buildInfo(LocalGallery gallery) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gallery.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.2)),
          const Expanded(child: SizedBox()),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(gallery.time), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Text('${gallery.pageCount} P', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))],
          ),
        ],
      ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
    );
  }

  void _showBottomSheet(LocalGallery gallery, int index, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              _handleRemoveItem(context, gallery);
              backRoute();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
      ),
    );
  }

  void _handleRemoveItem(BuildContext context, LocalGallery gallery) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedTitle2AnimationController.remove(gallery.title);
        removedTitle2Animation.remove(gallery.title);

        Get.engine.addPostFrameCallback((_) {
          localGalleryService.deleteGallery(gallery);
        });
      }
    });
    removedTitle2AnimationController[gallery.title] = controller;
    removedTitle2Animation[gallery.title] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));

    localGalleryService.update([LocalGalleryService.refreshId]);
  }

  void _goToReadPage(LocalGallery gallery) {
    int readIndexRecord = storageService.read('readIndexRecord::${gallery.title}') ?? 0;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.local,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: gallery.pageCount,
        images: localGalleryService.gallerys.firstWhere((g) => g.title == gallery.title).images,
      ),
    );
  }
}
