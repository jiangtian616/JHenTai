import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../mixin/archive/archive_download_page_state_mixin.dart';
import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';
import '../mixin/grid_download_page_state_mixin.dart';

class ArchiveGridDownloadPageState with Scroll2TopStateMixin, MultiSelectDownloadPageStateMixin, ArchiveDownloadPageStateMixin, GridBasePageState {
  @override
  List<String> get allRootGroups => Get.find<ArchiveDownloadService>().allGroups;

  @override
  List<ArchiveDownloadedData> galleryObjectsWithGroup(String groupName) => Get.find<ArchiveDownloadService>()
      .archives
      .where((archive) => Get.find<ArchiveDownloadService>().archiveDownloadInfos[archive.gid]?.group == groupName)
      .toList();
}
