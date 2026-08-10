import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../model/gallery_image.dart';
import '../../model/gallery_thumbnail.dart';
import '../../service/gallery_download/gallery_download_service.dart';
import '../../setting/read_setting.dart';
import '../../widget/loading_state_indicator.dart';

class ReadPageState with ScrollStatusListerState {
  /// gallery info
  final ReadPageInfo readPageInfo = Get.arguments;

  /// property used for parsing and loading
  int thumbnailsCountPerPage = SiteSetting.thumbnailsCountPerPage.value;
  late List<GalleryThumbnail?> thumbnails;

  /// Backing field for [images] in modes that own their list (online /
  /// archive / local). Downloaded mode reads directly from the service's
  /// resident [GalleryDownloadInfo.images] via the [images] getter, so
  /// mutations (parse / download / evict) flow through without snapshot
  /// re-sync.
  late List<GalleryImage?> _images;

  /// Image access for the read page.
  ///
  /// - Downloaded mode: returns the live [GalleryDownloadInfo.images] list
  ///   from the download service (or a null-padded fallback when the gallery
  ///   was evicted / not yet loaded). This is the single source of truth —
  ///   parse / download / status updates mutate that list in place, so the
  ///   read page picks them up via GetX update IDs without re-snapshotting.
  /// - Online / archive / local modes: return [_images], which the read
  ///   page logic owns and mutates directly.
  List<GalleryImage?> get images {
    if (readPageInfo.mode == ReadMode.downloaded) {
      final GalleryDownloadInfo? info = galleryDownloadService.galleryDownloadInfos[readPageInfo.gid!];
      return info?.images ?? List<GalleryImage?>.filled(readPageInfo.pageCount, null, growable: true);
    }
    return _images;
  }

  /// Write access for online mode (parse / reload). Downloaded mode is
  /// read-only from the read page's perspective — mutations go through
  /// the download service.
  set images(List<GalleryImage?> value) => _images = value;

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

  ReadPageState() {
    thumbnails = List.generate(readPageInfo.pageCount, (_) => null, growable: true);

    if (readPageInfo.mode == ReadMode.online) {
      _images = List.generate(readPageInfo.pageCount, (_) => null);
    }

    if (readPageInfo.mode == ReadMode.downloaded) {
      /// Caller ([ReadPageLogic.init]) must have called `ensureImagesLoaded()`
      /// first so the service's [GalleryDownloadInfo.images] is resident.
      /// The [images] getter reads that list directly — no snapshot.
      _images = List.generate(readPageInfo.pageCount, (_) => null);
    }

    if (readPageInfo.mode == ReadMode.archive || readPageInfo.mode == ReadMode.local) {
      _images = readPageInfo.images!.cast<GalleryImage?>();
    }

    parseImageHrefsStates = List.generate(readPageInfo.pageCount, (_) => LoadingState.idle);
    parseImageUrlStates = List.generate(readPageInfo.pageCount, (_) => LoadingState.idle);
    imageContainerSizes = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);
    parseImageUrlErrorMsg = List.generate(readPageInfo.pageCount, (_) => null);

    useSuperResolution = readPageInfo.useSuperResolution;
  }
}
