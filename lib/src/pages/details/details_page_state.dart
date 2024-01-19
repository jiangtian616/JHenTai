import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class DetailsPageState with Scroll2TopStateMixin {
  /// initial param
  late GalleryUrl galleryUrl;

  /// initial param
  /// may be null if we don't enter detail page from gallery list
  /// may be updated after we get the gallery details
  Gallery? gallery;

  GalleryDetail? galleryDetails;

  /// used for rating
  String? apikey;

  int nextPageIndexToLoadThumbnails = 1;
  LoadingState loadingState = LoadingState.idle;
  LoadingState loadingThumbnailsState = LoadingState.idle;
  LoadingState favoriteState = LoadingState.idle;
  LoadingState ratingState = LoadingState.idle;

  String? errorMessage;
}
