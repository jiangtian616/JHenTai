import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../service/gallery_download_service.dart';
import '../../setting/read_setting.dart';
import '../../widget/loading_state_indicator.dart';

class ReadPageState with ScrollStatusListerState {
  /// gallery info
  final ReadPageInfo readPageInfo = Get.arguments;

  /// property used for parsing and loading
  int thumbnailsCountPerPage = SiteSetting.thumbnailsCountPerPage.value;
  late List<GalleryThumbnail?> thumbnails;
  late List<GalleryImage?> images;

  late List<LoadingState> parseImageHrefsStates;
  late List<LoadingState> parseImageUrlStates;
  late List<Size?> imageContainerSizes;
  String? parseImageHrefErrorMsg;
  late List<String?> parseImageUrlErrorMsg;

  bool autoMode = false;
  bool isMenuOpen = false;
  Battery battery = Battery();
  int batteryLevel = 100;
  bool useSuperResolution = false;
  bool displayFirstPageAlone = readSetting.displayFirstPageAlone.value;
  FocusNode focusNode = FocusNode();

  late Size displayRegionSize;

  final ItemPositionsListener thumbnailPositionsListener = ItemPositionsListener.create();
  final ItemScrollController thumbnailsScrollController = ItemScrollController();
  final ScrollOffsetController thumbnailsScrollOffsetController = ScrollOffsetController();

  /// Track whether we own the images list (true for online/archive/local, false for downloaded)
  /// In downloaded mode, images is a REFERENCE to galleryDownloadService's data
  late final bool _ownsImagesList;

  ReadPageState() {
    thumbnails = List.generate(readPageInfo.pageCount, (_) => null, growable: true);

    if (readPageInfo.mode == ReadMode.online) {
      images = List.generate(readPageInfo.pageCount, (_) => null);
      _ownsImagesList = true;
    } else if (readPageInfo.mode == ReadMode.downloaded) {
      // IMPORTANT: This is a REFERENCE to galleryDownloadService's data
      // We do NOT own this list and MUST NOT clear it
      images = galleryDownloadService.galleryDownloadInfos[readPageInfo.gid]!.images;
      _ownsImagesList = false;
    } else if (readPageInfo.mode == ReadMode.archive || readPageInfo.mode == ReadMode.local) {
      images = readPageInfo.images!.cast<GalleryImage?>();
      _ownsImagesList = true;
    } else {
      // Defensive: handle any future ReadMode additions
      images = [];
      _ownsImagesList = true;
    }

    parseImageHrefsStates = List.generate(readPageInfo.pageCount, (_) => LoadingState.idle);
    parseImageUrlStates = List.generate(readPageInfo.pageCount, (_) => LoadingState.idle);
    imageContainerSizes = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);

    useSuperResolution = readPageInfo.useSuperResolution;
  }

  /// Clear all lists to release memory
  /// IMPORTANT: Only clears lists we OWN, not shared references
  void dispose() {
    thumbnails.clear();

    // CRITICAL: Only clear images if we own the list
    // Downloaded mode uses a reference to galleryDownloadService's data
    if (_ownsImagesList) {
      images.clear();
    }

    parseImageHrefsStates.clear();
    parseImageUrlStates.clear();
    imageContainerSizes.clear();
    parseImageUrlErrorMsg.clear();

    focusNode.dispose();
  }
}
