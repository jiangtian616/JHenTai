import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'widget/eh_scrollable_positioned_list.dart' as mine;

class ReadPageState {
  /// local / online
  late String type;

  late int initialIndex;
  late int pageCount;
  late int readIndexRecord;

  late int gid;
  late String galleryUrl;
  late List<Rxn<GalleryThumbnail>> thumbnails;
  LoadingState imageHrefParsingState = LoadingState.idle;
  late List<Rxn<GalleryImage>> images;
  List<Rx<LoadingState>>? imageUrlParsingStates;
  late List<RxnString> errorMsg;

  bool isMenuOpen = false;

  final mine.ItemScrollController itemScrollController = mine.ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  final PhotoViewScaleStateController photoViewScaleStateController = PhotoViewScaleStateController();

  PageController? pageController;

  TextStyle readPageTextStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 12,
      decoration: TextDecoration.none,
    );
  }
}
