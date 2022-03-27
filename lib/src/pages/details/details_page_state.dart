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
  late LoadingState loadingDetailsState;
  late LoadingState loadingThumbnailsState;
  late LoadingState addFavoriteState;

  DetailsPageState() {
    nextPageIndexToLoadThumbnails = 1;
    loadingDetailsState = LoadingState.idle;
    loadingThumbnailsState = LoadingState.idle;
    addFavoriteState = LoadingState.idle;
  }

  /// called when refresh
  void refresh() {
    galleryDetails = null;
    nextPageIndexToLoadThumbnails = 1;
  }
}
