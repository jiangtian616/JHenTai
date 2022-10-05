import 'dart:io' as io;
import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:path/path.dart';

import '../../../model/read_page_info.dart';
import '../../../routes/routes.dart';
import '../../../service/local_gallery_service.dart';
import '../../../service/storage_service.dart';
import '../../../setting/download_setting.dart';
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
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();
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
    state.removedGalleryTitles.add(gallery.title);
    update([bodyId]);
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
    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(gallery.path);
    } else {
      String storageKey = 'readIndexRecord::${gallery.title}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.local,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          pageCount: gallery.pageCount,
          readProgressRecordStorageKey: storageKey,
          images: localGalleryService.allGallerys.firstWhere((g) => g.title == gallery.title).images,
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

  Future<void> handleRefreshLocalGallery() async {
    int addCount = await Get.find<LocalGalleryService>().refreshLocalGallerys();
    state.currentPath = DownloadSetting.downloadPath.value;

    update([bodyId]);

    toast('${'newGalleryCount'.tr}: $addCount');
  }
}
