import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/model/reader_bookmark.dart';
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

  /// online mode: image indices whose bytes failed to load. Used by the batch
  /// retry feature to know which images actually need reloading.
  final Set<int> failedOnlineImageIndices = <int>{};

  /// Online images whose full-resolution bytes have completed loading. The
  /// progressive pipeline drops its thumbnail layer for these indices.
  final Set<int> loadedOnlineImageIndices = <int>{};

  /// Image indices whose translation overlay is active in this reading session.
  final Map<int, ImageTranslationRequest> imageTranslationRequests = {};

  /// Whether the inline translation overlay is currently visible for this
  /// reading session (toggled from the read-page top menu).
  bool showImageTranslationOverlay = true;

  bool autoMode = false;
  bool isMenuOpen = false;
  Battery battery = Battery();
  int batteryLevel = 100;
  bool useSuperResolution = false;
  final Map<int, String> readerSuperResolutionPaths = <int, String>{};
  bool showReaderSuperResolution = true;
  List<ReaderBookmark> readerBookmarks = <ReaderBookmark>[];
  bool displayFirstPageAlone = readSetting.displayFirstPageAlone.value;
  FocusNode focusNode = FocusNode();

  late Size displayRegionSize;

  final ItemPositionsListener thumbnailPositionsListener =
      ItemPositionsListener.create();
  final ItemScrollController thumbnailsScrollController =
      ItemScrollController();
  final ScrollOffsetController thumbnailsScrollOffsetController =
      ScrollOffsetController();

  ReadPageState() {
    thumbnails = List.generate(
      readPageInfo.pageCount,
      (_) => null,
      growable: true,
    );

    if (readPageInfo.mode == ReadMode.online) {
      images = List.generate(readPageInfo.pageCount, (_) => null);
    }

    if (readPageInfo.mode == ReadMode.downloaded) {
      images =
          galleryDownloadService.galleryDownloadInfos[readPageInfo.gid]!.images;
    }

    if (readPageInfo.mode == ReadMode.archive ||
        readPageInfo.mode == ReadMode.local) {
      images = readPageInfo.images!.cast<GalleryImage?>();
    }

    parseImageHrefsStates = List.generate(
      readPageInfo.pageCount,
      (_) => LoadingState.idle,
    );
    parseImageUrlStates = List.generate(
      readPageInfo.pageCount,
      (_) => LoadingState.idle,
    );
    imageContainerSizes = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);

    useSuperResolution = readPageInfo.useSuperResolution;
  }
}
