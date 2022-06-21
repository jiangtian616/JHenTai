enum ArchiveStatus {
  none,
  paused,
  unlocking,
  waitingForDownloadPageUrl,
  waitingForDownloadUrl,
  downloading,
  downloaded,
  unpacking,
  completed,
}

class GalleryArchive {
  int? gpCount;
  int? creditCount;

  String originalCost;
  String originalSize;
  String downloadOriginalHint;

  String? resampleCost;
  String? resampleSize;
  String downloadResampleHint;

  GalleryArchive({
    this.gpCount,
    this.creditCount,
    required this.originalCost,
    required this.originalSize,
    required this.downloadOriginalHint,
    this.resampleCost,
    this.resampleSize,
    required this.downloadResampleHint,
  });
}
