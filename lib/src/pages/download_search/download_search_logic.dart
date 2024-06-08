import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../service/archive_download_service.dart';
import '../../service/gallery_download_service.dart';
import 'download_search_state.dart';

class DownloadSearchLogic extends GetxController {
  final DownloadSearchState state = DownloadSearchState();

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archivedDownloadService = Get.find();
  
  @override
  void onInit() {
    state.searchFocusNode = FocusNode();
    super.onInit();
  }

  @override
  void onClose() {
    state.searchFocusNode.dispose();
    super.onClose();
  }
}
