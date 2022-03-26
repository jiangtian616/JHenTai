import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_details.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

enum RanklistType {
  allTime,
  year,
  month,
  day,
}

class RanklistViewState {
  late RanklistType ranklistType;
  late Map<RanklistType, List<Gallery>> ranklistGallery;
  late Map<RanklistType, List<GalleryDetails>> ranklistGalleryDetails;
  late Map<RanklistType, List<String>> ranklistGalleryDetailsApikey;

  late Map<RanklistType, LoadingState> getRanklistLoadingState;

  RanklistViewState() {
    ranklistType = RanklistType.allTime;
    ranklistGallery = <RanklistType, List<Gallery>>{
      RanklistType.allTime: <Gallery>[],
      RanklistType.year: <Gallery>[],
      RanklistType.month: <Gallery>[],
      RanklistType.day: <Gallery>[],
    };
    ranklistGalleryDetails = <RanklistType, List<GalleryDetails>>{
      RanklistType.allTime: <GalleryDetails>[],
      RanklistType.year: <GalleryDetails>[],
      RanklistType.month: <GalleryDetails>[],
      RanklistType.day: <GalleryDetails>[],
    };
    ranklistGalleryDetailsApikey = <RanklistType, List<String>>{
      RanklistType.allTime: <String>[],
      RanklistType.year: <String>[],
      RanklistType.month: <String>[],
      RanklistType.day: <String>[],
    };
    getRanklistLoadingState = <RanklistType, LoadingState>{
      RanklistType.allTime: LoadingState.idle,
      RanklistType.year: LoadingState.idle,
      RanklistType.month: LoadingState.idle,
      RanklistType.day: LoadingState.idle,
    };
    ;
  }
}
