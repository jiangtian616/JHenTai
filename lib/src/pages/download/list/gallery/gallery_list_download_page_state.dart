import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';

import '../../mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';

class GalleryListDownloadPageState with Scroll2TopStateMixin, GalleryDownloadPageStateMixin, MultiSelectDownloadPageStateMixin {
  Set<String> displayGroups = {};
  final Set<int> removedGids = {};
  final Set<int> removedGidsWithoutImages = {};
}
