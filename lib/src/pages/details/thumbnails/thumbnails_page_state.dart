import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../../../model/gallery_thumbnail.dart';
import '../../../widget/loading_state_indicator.dart';

class ThumbnailsPageState with Scroll2TopStateMixin {
  late int initialPageIndex;
  late int nextPageIndexToLoadThumbnails;

  List<GalleryThumbnail> thumbnails = [];

  /// if initialPageIndex is not 0, we need to compute the absolute index of the thumbnail
  List<int> absoluteIndexOfThumbnails = [];

  LoadingState loadingState = LoadingState.idle;

  ThumbnailsPageState() {
    initialPageIndex = Get.arguments;
    nextPageIndexToLoadThumbnails = Get.arguments;
  }
}
