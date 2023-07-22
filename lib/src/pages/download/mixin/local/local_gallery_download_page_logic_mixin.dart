import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:path/path.dart';

import '../../../../config/ui_config.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/local_gallery_service.dart';
import '../../../../service/storage_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../utils/process_util.dart';
import '../../../../utils/route_util.dart' as route;
import '../../../../utils/toast_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/loading_state_indicator.dart';

mixin LocalGalleryDownloadPageLogicMixin on GetxController {
  final String bodyId = 'bodyId';

  String get currentPath;

  set currentPath(String value);

  final LocalGalleryService localGalleryService = Get.find<LocalGalleryService>();
  final StorageService storageService = Get.find<StorageService>();

  bool get isAtRootPath => currentPath == LocalGalleryService.rootPath;

  int computeItemCount() {
    return isAtRootPath
        ? localGalleryService.rootDirectories.length
        : (localGalleryService.path2GalleryDir[currentPath]?.length ?? 0) + (localGalleryService.path2SubDir[currentPath]?.length ?? 0) + 1;
  }

  int computeCurrentDirectoryCount() {
    if (isAtRootPath) {
      return localGalleryService.rootDirectories.length;
    }

    return localGalleryService.path2SubDir[currentPath]?.length ?? 0;
  }

  String computeChildPath(int index) {
    if (isAtRootPath) {
      return localGalleryService.rootDirectories[index];
    }

    return localGalleryService.path2SubDir[currentPath]![index];
  }

  Future<void> handleRemoveItem(LocalGallery gallery) async {
    bool? result = await Get.dialog(EHDialog(title: 'deleteLocalGalleryHint'.tr + '?'));
    if (result == true) {
      doRemoveItem(gallery);
    }
  }

  Future<void> doRemoveItem(LocalGallery gallery) async {
    update([bodyId]);
  }

  void pushRoute(String dirName) {
    currentPath = join(currentPath, dirName);
    update([bodyId]);
  }

  void backRoute() {
    if (isAtRootPath) {
      return;
    }

    if (localGalleryService.rootDirectories.contains(currentPath)) {
      currentPath = LocalGalleryService.rootPath;
    } else {
      currentPath = Directory(currentPath).parent.path;
    }

    update([bodyId]);
  }

  void goToReadPage(LocalGallery gallery) {
    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(gallery.path);
    } else {
      String storageKey = 'readIndexRecord::${gallery.gid ?? gallery.title}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;

      List<GalleryImage> images = localGalleryService.getGalleryImages(gallery);

      route.toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.local,
          galleryTitle: gallery.title,
          initialIndex: readIndexRecord,
          currentImageIndex: readIndexRecord,
          pageCount: images.length,
          readProgressRecordStorageKey: storageKey,
          images: localGalleryService.getGalleryImages(gallery),
          useSuperResolution: false,
        ),
      );
    }
  }

  void goToDetailPage(LocalGallery gallery) {
    route.toRoute(
      Routes.details,
      arguments: {'galleryUrl': gallery.galleryUrl},
    );
  }

  Future<void> handleRefreshLocalGallery() async {
    if (localGalleryService.loadingState == LoadingState.loading) {
      return;
    }

    int preCount = localGalleryService.allGallerys.length;

    localGalleryService.refreshLocalGallerys().then((_) {
      currentPath = LocalGalleryService.rootPath;
      update([bodyId]);
      toast('${'newGalleryCount'.tr}: ${localGalleryService.allGallerys.length - preCount}');
    });
  }

  void showBottomSheet(LocalGallery gallery, BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
            onPressed: () {
              route.backRoute();
              handleRemoveItem(gallery);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: route.backRoute,
        ),
      ),
    );
  }

  String transformDisplayPath(String path) {
    List<String> parts = path.split(separator);
    if (parts.length > 2) {
      return '.../${parts[parts.length - 2]}/${parts[parts.length - 1]}'.breakWord;
    } else {
      return path.breakWord;
    }
  }
}
