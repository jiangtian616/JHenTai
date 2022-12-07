import 'package:get/get.dart';
import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../common/archive/archive_download_page_logic_mixin.dart';
import 'archive_list_download_page_state.dart';

class ArchiveListDownloadPageLogic extends GetxController with Scroll2TopLogicMixin, ArchiveDownloadPageLogicMixin {
  @override
  ArchiveListDownloadPageState state = ArchiveListDownloadPageState();

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

    storageService.write('displayArchiveGroups', state.displayGroups.toList());
    update(['$groupId::$groupName']);
  }

  @override
  Future<void> doRenameGroup(String oldGroup, String newGroup) async {
    state.displayGroups.remove(oldGroup);
    return super.doRenameGroup(oldGroup, newGroup);
  }

  @override
  void handleRemoveItem(ArchiveDownloadedData archive) {
    state.removedGids.add(archive.gid);
    super.handleRemoveItem(archive);
  }
}
