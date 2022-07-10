import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
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
  late Map<RanklistType, List<GalleryDetail>> ranklistGalleryDetails;
  late Map<RanklistType, List<String>> ranklistGalleryDetailsApikey;

  late Map<RanklistType, LoadingState> getRanklistLoadingState;

  Key listKey = UniqueKey();

  RanklistViewState() {
    ranklistType = RanklistType.day;
    ranklistGallery = <RanklistType, List<Gallery>>{
      RanklistType.allTime: <Gallery>[],
      RanklistType.year: <Gallery>[],
      RanklistType.month: <Gallery>[],
      RanklistType.day: <Gallery>[],
    };
    ranklistGalleryDetails = <RanklistType, List<GalleryDetail>>{
      RanklistType.allTime: <GalleryDetail>[],
      RanklistType.year: <GalleryDetail>[],
      RanklistType.month: <GalleryDetail>[],
      RanklistType.day: <GalleryDetail>[],
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
  }
}
