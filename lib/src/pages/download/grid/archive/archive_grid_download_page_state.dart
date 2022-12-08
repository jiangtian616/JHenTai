import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';

import '../../../../database/database.dart';
import '../base/grid_base_page_state.dart';

class ArchiveGridDownloadPageState extends GridBasePageState {
  @override
  List<String> get allRootGroups => Get.find<ArchiveDownloadService>().allGroups;

  @override
  List<ArchiveDownloadedData> galleryObjectsWithGroup(String groupName) => Get.find<ArchiveDownloadService>()
      .archives
      .where((archive) => Get.find<ArchiveDownloadService>().archiveDownloadInfos[archive.gid]?.group == groupName)
      .toList();
}
