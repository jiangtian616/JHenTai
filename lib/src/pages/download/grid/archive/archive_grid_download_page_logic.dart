import 'dart:math';

import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/archive/archive_download_page_state_mixin.dart';
import 'package:jhentai/src/service/archive_download_service.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/toast_util.dart';
import '../../mixin/archive/archive_download_page_logic_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_logic_mixin.dart';
import '../mixin/grid_download_page_service_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';
import 'archive_grid_download_page_state.dart';

class ArchiveGridDownloadPageLogic extends GetxController
    with Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<ArchiveDownloadedData>, ArchiveDownloadPageLogicMixin, GridBasePageLogic {
  final ArchiveGridDownloadPageState state = ArchiveGridDownloadPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  GridBasePageState get gridBasePageState => state;

  @override
  ArchiveDownloadPageStateMixin get archiveDownloadPageState => state;

  @override
  final ArchiveDownloadService archiveDownloadService = Get.find<ArchiveDownloadService>();

  @override
  GridBasePageServiceMixin get galleryService => archiveDownloadService;

  void handleTapTitle(ArchiveDownloadedData archive) {
    if (multiSelectDownloadPageState.inMultiSelectMode) {
      toggleSelectItem(archive.gid);
    } else {
      goToDetailPage(archive);
    }
  }

  @override
  void handleRemoveItem(ArchiveDownloadedData archive) {
    archiveDownloadService.deleteArchive(archive).then((_) => super.handleRemoveItem(archive));
  }

  void goToDetailPage(ArchiveDownloadedData archive) {
    toRoute(
      Routes.details,
      arguments: {
        'gid': archive.gid,
        'galleryUrl': archive.galleryUrl,
      },
    );
  }

  @override
  void toggleEditMode() {
    if (!gridBasePageState.inEditMode) {
      exitSelectMode();
      toast('drag2sort'.tr);
    }
    gridBasePageState.inEditMode = !gridBasePageState.inEditMode;
    update([bodyId, editButtonId]);
  }

  @override
  void selectAllItem() {
    multiSelectDownloadPageState.selectedGids.clear();
    multiSelectDownloadPageState.selectedGids.addAll(state.currentGalleryObjects.map((archive) => archive.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids.map((gid) => '$itemCardId::$gid').toList());
  }

  @override
  Future<void> saveGalleryOrderAfterDrag(int beforeIndex, int afterIndex) async {
    List<ArchiveDownloadedData> archives = state.currentGalleryObjects.cast();

    /// default order is 0, we must assign current order to the archive first
    for (int i = 0; i < archives.length; i++) {
      ArchiveDownloadedData archive = archives[i];
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid]!;
      archiveDownloadInfo.sortOrder = i;
    }

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

    await archiveDownloadService.updateArchiveOrder(archives);
  }

  @override
  Future<void> saveGroupOrderAfterDrag(int beforeIndex, int afterIndex) {
    return archiveDownloadService.updateGroupOrder(beforeIndex, afterIndex);
  }
}
