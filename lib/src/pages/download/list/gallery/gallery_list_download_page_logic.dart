import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_logic_mixin.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'gallery_list_download_page_state.dart';

class GalleryListDownloadPageLogic extends GetxController
    with Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<GalleryDownloadedData>, GalleryDownloadPageLogicMixin {
  GalleryListDownloadPageState state = GalleryListDownloadPageState();

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => state;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  void onInit() {
    super.onInit();
    state.displayGroups = Set.from(storageService.read('displayArchiveGroups') ?? ['default'.tr]);
  }

  void toggleDisplayGroups(String groupName) {
    if (state.displayGroups.contains(groupName)) {
      state.displayGroups.remove(groupName);
    } else {
      state.displayGroups.add(groupName);
    }

    storageService.write('displayGalleryGroups', state.displayGroups.toList());
    update(['$groupId::$groupName']);
  }

  @override
  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
    state.displayGroups.remove(oldGroup);
    return super.doRenameGroup(oldGroup, newGroup);
  }

  @override
  void handleRemoveItem(GalleryDownloadedData gallery, bool deleteImages) {
    if (deleteImages) {
      state.removedGids.add(gallery.gid);
    } else {
      state.removedGidsWithoutImages.add(gallery.gid);
    }

    state.selectedGids.remove(gallery.gid);

    super.handleRemoveItem(gallery, deleteImages);
  }

  @override
  void selectAllItem() {
    List<GalleryDownloadedData> gallerys = [];
    for (String group in state.displayGroups) {
      gallerys.addAll(downloadService.gallerysWithGroup(group));
    }
    
    multiSelectDownloadPageState.selectedGids.addAll(gallerys.map((gallery) => gallery.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids.map((gid) => '$itemCardId::$gid').toList());
  }
}
