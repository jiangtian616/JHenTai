import 'gallery_image.dart';

enum ReadMode { downloaded, online, archive, local }

class ReadPageInfo {
  ReadMode mode;

  int? gid;

  String? galleryUrl;

  int initialIndex;

  int currentIndex;

  int pageCount;

  /// used for archive
  bool isOriginal;

  /// used for archive&local
  List<GalleryImage>? images;

  ReadPageInfo({
    required this.mode,
    this.gid,
    this.galleryUrl,
    required this.initialIndex,
    required this.currentIndex,
    required this.pageCount,
    this.isOriginal = false,
    this.images,
  });
}
