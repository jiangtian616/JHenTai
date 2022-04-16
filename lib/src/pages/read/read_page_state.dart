import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../service/download_service.dart';
import 'widget/eh_scrollable_positioned_list.dart' as mine;

class ReadPageState {
  /// property passed by other page
  late String mode;
  late int gid;
  late String galleryUrl;
  late int initialIndex;
  late int pageCount;

  /// property used for parsing and loading
  late List<GalleryThumbnail?> thumbnails;
  LoadingState parseImageHrefsState = LoadingState.idle;
  late List<GalleryImage?> images;
  late List<LoadingState> parseImageUrlStates;
  late List<String?> errorMsg;

  /// property used for build page
  late int readIndexRecord;
  bool isMenuOpen = false;
  final mine.ItemScrollController itemScrollController = mine.ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  final PhotoViewScaleStateController photoViewScaleStateController = PhotoViewScaleStateController();
  PageController? pageController;

  ReadPageState() {
    /// property passed by other page
    mode = Get.parameters['mode']!;
    gid = int.parse(Get.parameters['gid']!);
    galleryUrl = Get.parameters['galleryUrl']!;
    initialIndex = int.parse(Get.parameters['initialIndex']!);
    pageCount = int.parse(Get.parameters['pageCount']!);

    /// property used for build page
    readIndexRecord = Get.find<StorageService>().read('readIndexRecord::${gid}') ?? 0;
    pageController = PageController(initialPage: initialIndex);

    /// property used for parsing and loading
    if (mode == 'local') {
      thumbnails =
          Get.find<DownloadService>().gid2ImageHrefs[gid] ?? List.generate(pageCount, (index) => null, growable: true);
      images = Get.arguments ?? Get.find<DownloadService>().gid2Images[gid]!;
    } else {
      thumbnails = List.generate(pageCount, (index) => null, growable: true);
      images = List.generate(pageCount, (index) => null);
      parseImageUrlStates = List.generate(pageCount, (index) => LoadingState.idle);
    }
    errorMsg = List.generate(pageCount, (index) => null);
  }

  TextStyle readPageTextStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 12,
      decoration: TextDecoration.none,
    );
  }
}
