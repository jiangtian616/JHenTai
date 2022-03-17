import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_details.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class DetailsPageState {
  Gallery? gallery;

  GalleryDetails? galleryDetails;

  /// used to rating
  late String apikey;

  int? thumbnailsPageCount;
  late int nextPageNoToLoadThumbnails;

  late LoadingState loadingDetailsState;
  late LoadingState loadingThumbnailsState;
  late LoadingState addFavoriteState;

  DetailsPageState() {
    loadingDetailsState = LoadingState.idle;
    loadingThumbnailsState = LoadingState.idle;
    addFavoriteState = LoadingState.idle;
    nextPageNoToLoadThumbnails = 1;
  }

  /// called when refresh
  void refresh() {
    galleryDetails = null;
    nextPageNoToLoadThumbnails = 1;
  }
}
