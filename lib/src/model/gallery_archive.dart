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
  int gpCount;
  int creditCount;

  int originalCost;
  int resampleCost;

  String originalSize;
  String resampleSize;

  GalleryArchive({
    required this.gpCount,
    required this.creditCount,
    required this.originalCost,
    required this.resampleCost,
    required this.originalSize,
    required this.resampleSize,
  });
}
