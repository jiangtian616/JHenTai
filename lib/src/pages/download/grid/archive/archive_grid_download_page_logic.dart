import 'dart:math';

import 'package:get/get.dart';
import 'package:jhentai/src/pages/download/common/archive/archive_download_page_logic_mixin.dart';
import 'package:jhentai/src/pages/download/grid/base/grid_base_page_service_mixin.dart';
import 'package:jhentai/src/service/archive_download_service.dart';

import '../../../../database/database.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../base/grid_base_page_logic.dart';
import 'archive_grid_download_page_state.dart';

class ArchiveGridDownloadPageLogic extends GridBasePageLogic with ArchiveDownloadPageLogicMixin {
  @override
  final ArchiveGridDownloadPageState state = ArchiveGridDownloadPageState();

  @override
  final ArchiveDownloadService archiveDownloadService = Get.find<ArchiveDownloadService>();

  @override
  GridBasePageServiceMixin get galleryService => archiveDownloadService;

  @override
  void handleRemoveItem(ArchiveDownloadedData archive) {
    archiveDownloadService.deleteArchive(archive).then((_) => super.handleRemoveItem(archive));
  }

  void goToDetailPage(ArchiveDownloadedData archive) {
    toRoute(Routes.details, arguments: {'galleryUrl': archive.galleryUrl});
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex) async {
    List<ArchiveDownloadedData> archives = state.currentGalleryObjects.cast();

    int head = min(beforeIndex, afterIndex);
    int tail = max(beforeIndex, afterIndex);

    for (int index = head; index <= tail; index++) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archives[index].gid]!;

      if (index == beforeIndex) {
        archiveDownloadInfo.sortOrder = afterIndex;
      } else if (beforeIndex < afterIndex) {
        archiveDownloadInfo.sortOrder = index - 1;
      } else {
        archiveDownloadInfo.sortOrder = index + 1;
      }
    }

    await archiveDownloadService.updateArchiveOrder(archives.sublist(head, tail + 1));
  }

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) {
    return archiveDownloadService.updateGroupOrder(beforeIndex, afterIndex);
  }
}
