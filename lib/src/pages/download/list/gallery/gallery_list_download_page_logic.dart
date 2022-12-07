import 'package:get/get.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../common/gallery/gallery_download_page_logic_mixin.dart';
import 'gallery_list_download_page_state.dart';

class GalleryListDownloadPageLogic extends GetxController with Scroll2TopLogicMixin, GalleryDownloadPageLogicMixin {
  @override
  GalleryListDownloadPageState state = GalleryListDownloadPageState();

  @override
  void onInit() {
    super.onInit();
    state.displayGroups = Set.from(storageService.read('displayArchiveGroups') ?? ['default'.tr]);
  }

  @override
  void onClose() {
    super.onClose();

    state.scrollController.dispose();
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
    super.handleRemoveItem(gallery, deleteImages);
  }
}
