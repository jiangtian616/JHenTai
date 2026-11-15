import 'gallery_image.dart';

import '../setting/read_setting.dart';

enum ReadMode { downloaded, online, archive, local }

/// The gallery before or after the one being read, in the list read page is opened from
class AdjacentGallery {
  final String title;

  /// Null if the gallery can't be read anymore, e.g. it's deleted
  final Future<ReadPageInfo?> Function() loadReadPageInfo;

  const AdjacentGallery({required this.title, required this.loadReadPageInfo});
}

/// [next] is false for the previous gallery. Returns null if there is no more gallery in that direction
typedef AdjacentGalleryFinder = AdjacentGallery? Function(bool next);

class ReadPageInfo {
  ReadMode mode;

  /// null for local gallery
  int? gid;

  /// null for local gallery
  String? token;

  String galleryTitle;

  String? galleryUrl;

  int initialIndex;

  int currentImageIndex;

  int pageCount;

  /// used for archive
  bool isOriginal;

  String readProgressRecordStorageKey;

  /// used for archive&local
  List<GalleryImage>? images;

  /// used for initialize
  bool useSuperResolution;

  ReadDirection? readDirection;

  /// Used to switch to the previous or next gallery in read page, null if not supported
  AdjacentGalleryFinder? adjacentGalleryFinder;

  ReadPageInfo({
    required this.mode,
    this.gid,
    this.token,
    required this.galleryTitle,
    this.galleryUrl,
    required this.initialIndex,
    required this.pageCount,
    this.isOriginal = false,
    required this.readProgressRecordStorageKey,
    this.images,
    required this.useSuperResolution,
    this.readDirection,
    this.adjacentGalleryFinder,
  }) : currentImageIndex = initialIndex;
}
