import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../service/local_gallery_service.dart';
import '../../mixin/local/local_gallery_download_page_logic_mixin.dart';
import 'local_gallery_list_page_state.dart';

class LocalGalleryListPageLogic extends GetxController with Scroll2TopLogicMixin, LocalGalleryDownloadPageLogicMixin {
  LocalGalleryListPageState state = LocalGalleryListPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  String get currentPath => state.currentPath;

  @override
  set currentPath(String value) => state.currentPath = value;

  @override
  Future<void> doRemoveItem(LocalGallery gallery) async {
    state.removedGalleryTitles.add(gallery.title);
    super.doRemoveItem(gallery);
  }
}
