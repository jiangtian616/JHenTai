import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class DetailsPageState {
  Gallery? gallery;

  GalleryDetail? galleryDetails;

  /// used to rating
  late String apikey;

  late int thumbnailsPageCount;
  late int nextPageIndexToLoadThumbnails;
  late LoadingState loadingPageState;
  late LoadingState loadingDetailsState;
  late LoadingState loadingThumbnailsState;
  late LoadingState favoriteState;
  late LoadingState ratingState;

  DetailsPageState() {
    nextPageIndexToLoadThumbnails = 1;
    loadingPageState = LoadingState.loading;
    loadingDetailsState = LoadingState.idle;
    loadingThumbnailsState = LoadingState.idle;
    favoriteState = LoadingState.idle;
    ratingState = LoadingState.idle;
  }

  /// called when refresh
  void refresh() {
    galleryDetails = null;
    nextPageIndexToLoadThumbnails = 1;
  }
}
