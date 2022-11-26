import 'dart:io' as io;

import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';

import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/local_gallery_service.dart';
import '../../../service/storage_service.dart';
import '../../../setting/read_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/process_util.dart';
import '../../../utils/route_util.dart';
import '../../../utils/toast_util.dart';
import 'local_gallery_page_state.dart';

class LocalGalleryPageLogic extends GetxController with GetTickerProviderStateMixin, Scroll2TopLogicMixin {
  static const String appBarId = 'appBarId';
  static const String bodyId = 'bodyId';

  @override
  LocalGalleryPageState state = LocalGalleryPageState();

  final LocalGalleryService localGalleryService = Get.find<LocalGalleryService>();
  final StorageService storageService = Get.find<StorageService>();

  @override
  void onInit() {
    super.onInit();

    state.aggregateDirectories = storageService.read('LocalGalleryBody_AggregateDirectories') ?? state.aggregateDirectories;
    localGalleryService.refreshLocalGallerys().then((_) {
      state.loadingState = LoadingState.success;
      updateSafely([bodyId]);
    });
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();
  }

  int computeItemCount() {
    return state.aggregateDirectories
        ? localGalleryService.allGallerys.length
        : isAtRootPath()
            ? 1 + localGalleryService.rootDirectories.length
            : (localGalleryService.path2GalleryDir[state.currentPath]?.length ?? 0) +
                (localGalleryService.path2SubDir[state.currentPath]?.length ?? 0) +
                1;
  }

  int computeCurrentDirectoryCount() {
    if (isAtRootPath()) {
      return 1 + localGalleryService.rootDirectories.length;
    }

    return localGalleryService.path2SubDir[state.currentPath]?.length ?? 0;
  }

  String computeChildPath(int index) {
    if (isAtRootPath()) {
      return localGalleryService.rootDirectories[index];
    }

    return localGalleryService.path2SubDir[state.currentPath]![index];
  }

  Future<void> handleRemoveItem(LocalGallery gallery) async {
    bool? result = await Get.dialog(EHAlertDialog(title: 'deleteLocalGalleryHint'.tr + '?'));
    if (result == true) {
      state.removedGalleryTitles.add(gallery.title);
      update([bodyId]);
    }
  }

  void pushRoute(String dirName) {
    state.currentPath = join(state.currentPath, dirName);
    update([bodyId]);
  }

  void backRoute() {
    if (isAtRootPath()) {
      return;
    }

    if (localGalleryService.rootDirectories.contains(state.currentPath)) {
      state.currentPath = LocalGalleryService.rootPath;
    } else {
      state.currentPath = io.Directory(state.currentPath).parent.path;
    }

    update([bodyId]);
  }

  void goToReadPage(LocalGallery gallery) {
    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(gallery.path);
    } else {
      String storageKey = 'readIndexRecord::${gallery.title}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;

      List<GalleryImage> images = localGalleryService.getGalleryImages(gallery);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.local,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          pageCount: images.length,
          readProgressRecordStorageKey: storageKey,
          images: localGalleryService.getGalleryImages(gallery),
        ),
      );
    }
  }

  void toggleAggregateDirectory() {
    Log.info('toggleAggregateDirectory -> ${!state.aggregateDirectories}');

    state.aggregateDirectories = !state.aggregateDirectories;
    storageService.write('LocalGalleryBody_AggregateDirectories', state.aggregateDirectories);

    update([appBarId, bodyId]);
  }

  bool isAtRootPath() {
    return state.currentPath == LocalGalleryService.rootPath;
  }

  Future<void> handleRefreshLocalGallery() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely([bodyId]);

    localGalleryService.refreshLocalGallerys().then((int addCount) {
      state.loadingState = LoadingState.success;
      state.currentPath = LocalGalleryService.rootPath;
      update([bodyId]);
      toast('${'newGalleryCount'.tr}: $addCount');
    });
  }
}
