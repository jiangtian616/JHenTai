import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../mixin/archive/archive_download_page_logic_mixin.dart';
import '../../mixin/archive/archive_download_page_state_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_logic_mixin.dart';
import 'archive_list_download_page_state.dart';

class ArchiveListDownloadPageLogic extends GetxController
    with Scroll2TopLogicMixin, MultiSelectDownloadPageLogicMixin<ArchiveDownloadedData>, ArchiveDownloadPageLogicMixin {
  ArchiveListDownloadPageState state = ArchiveListDownloadPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  ArchiveDownloadPageStateMixin get archiveDownloadPageState => state;

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

  @override
  void handleResumeAllTasks() {
    archiveDownloadService.resumeAllDownloadArchive();
  }

  @override
  void selectAllItem() {
    List<ArchiveDownloadedData> archives = [];
    for (String group in state.displayGroups) {
      archives.addAll(archiveDownloadService.archivesWithGroup(group));
    }
    
    multiSelectDownloadPageState.selectedGids.addAll(archives.map((archive) => archive.gid));
    updateSafely(multiSelectDownloadPageState.selectedGids.map((gid) => '$itemCardId::$gid').toList());
  }
}
