import 'dart:io' as io;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';

import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/local_gallery_service.dart';
import '../../../service/storage_service.dart';
import '../../../setting/download_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/toast_util.dart';
import 'local_gallery_page_state.dart';

class LocalGalleryPageLogic extends GetxController with GetTickerProviderStateMixin {
  static const String pageId = 'pageId';
  static const String bodyId = 'bodyId';

  LocalGalleryPageState state = LocalGalleryPageState();

  final LocalGalleryService localGalleryService = Get.find<LocalGalleryService>();
  final StorageService storageService = Get.find<StorageService>();

  final Map<String, AnimationController> removedTitle2AnimationController = {};
  final Map<String, Animation<double>> removedTitle2Animation = {};

  @override
  void onInit() {
    super.onInit();

    state.aggregateDirectories = storageService.read('LocalGalleryBody_AggregateDirectories') ?? state.aggregateDirectories;
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();

    for (AnimationController controller in removedTitle2AnimationController.values) {
      controller.dispose();
    }
  }

  int computeItemCount() {
    return state.aggregateDirectories
        ? localGalleryService.allGallerys.length
        : (localGalleryService.path2Gallerys[state.currentPath]?.length ?? 0) +
            (localGalleryService.path2Directories[state.currentPath]?.length ?? 0) +
            1;
  }

  int computeCurrentDirectoryCount() {
    return localGalleryService.path2Directories[state.currentPath]?.length ?? 0;
  }

  String computeChildPath(int index) {
    return localGalleryService.path2Directories[state.currentPath]![index];
  }

  void handleRemoveItem(LocalGallery gallery) {
    AnimationController controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        removedTitle2AnimationController.remove(gallery.title);
        removedTitle2Animation.remove(gallery.title);

        Get.engine.addPostFrameCallback((_) {
          localGalleryService.deleteGallery(gallery, state.currentPath);
          update([bodyId]);
        });
      }
    });
    removedTitle2AnimationController[gallery.title] = controller;
    removedTitle2Animation[gallery.title] = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(curve: Curves.easeOut, parent: controller));
  }

  void pushRoute(String dirName) {
    state.currentPath = join(state.currentPath, dirName);
    update([bodyId]);
  }

  void backRoute() {
    if (state.currentPath == DownloadSetting.downloadPath.value) {
      return;
    }
    state.currentPath = io.Directory(state.currentPath).parent.path;
    update([bodyId]);
  }

  void goToReadPage(LocalGallery gallery) {
    int readIndexRecord = storageService.read('readIndexRecord::${gallery.title}') ?? 0;

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.local,
        initialIndex: readIndexRecord,
        currentIndex: readIndexRecord,
        pageCount: gallery.pageCount,
        images: localGalleryService.allGallerys.firstWhere((g) => g.title == gallery.title).images,
      ),
    );
  }

  void toggleAggregateDirectory() {
    Log.info('toggleAggregateDirectory -> ${!state.aggregateDirectories}');

    state.aggregateDirectories = !state.aggregateDirectories;
    storageService.write('LocalGalleryBody_AggregateDirectories', !state.aggregateDirectories);

    update([bodyId]);
  }

  Future<void> handleRefreshLocalGallery() async {
    int addCount = await Get.find<LocalGalleryService>().refreshLocalGallerys();
    state.currentPath = DownloadSetting.downloadPath.value;

    update([bodyId]);

    toast('${'newGalleryCount'.tr}: $addCount');
  }

  void scroll2Top() {
    if (state.scrollController.hasClients) {
      state.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }
  }
}
