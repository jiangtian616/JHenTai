enum ReadMode { local, online, archive }

class ReadPageInfo {
  ReadMode mode;

  int gid;

  String galleryUrl;

  int initialIndex;

  int currentIndex;

  int pageCount;

  /// used for archive
  bool isOriginal;

  ReadPageInfo({
    required this.mode,
    required this.gid,
    required this.galleryUrl,
    required this.initialIndex,
    required this.currentIndex,
    required this.pageCount,
    this.isOriginal = false,
  });
}
