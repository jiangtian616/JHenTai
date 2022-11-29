import 'gallery_image.dart';

enum ReadMode { downloaded, online, archive, local }

class ReadPageInfo {
  ReadMode mode;

  int? gid;

  String galleryTitle;

  String? galleryUrl;

  int initialIndex;

  int currentIndex;

  int pageCount;

  /// used for archive
  bool isOriginal;

  String readProgressRecordStorageKey;

  /// used for archive&local
  List<GalleryImage>? images;

  ReadPageInfo({
    required this.mode,
    this.gid,
    required this.galleryTitle,
    this.galleryUrl,
    required this.initialIndex,
    required this.currentIndex,
    required this.pageCount,
    this.isOriginal = false,
    required this.readProgressRecordStorageKey,
    this.images,
  });
}
