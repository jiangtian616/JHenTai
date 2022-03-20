enum DownloadStatus {
  none,
  paused,
  downloading,
  downloaded,
  downloadFailed,
}

class GalleryImage {
  String url;
  double height;
  double width;

  String? path;
  DownloadStatus downloadStatus;

  GalleryImage({
    required this.url,
    required this.height,
    required this.width,
    this.path,
    this.downloadStatus = DownloadStatus.none,
  });
}
