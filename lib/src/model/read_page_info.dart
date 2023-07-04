import 'gallery_image.dart';

enum ReadMode { downloaded, online, archive, local }

class ReadPageInfo {
  ReadMode mode;
  
  /// null for local gallery
  int? gid;

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
  
  ReadPageInfo({
    required this.mode,
    this.gid,
    required this.galleryTitle,
    this.galleryUrl,
    required this.initialIndex,
    required this.currentImageIndex,
    required this.pageCount,
    this.isOriginal = false,
    required this.readProgressRecordStorageKey,
    this.images,
    required this.useSuperResolution,
  });
}
