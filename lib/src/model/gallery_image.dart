enum DownloadStatus {
  none,
  switching,
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

  Map<String, dynamic> toJson() {
    return {
      "url": this.url,
      "height": this.height,
      "width": this.width,
      "path": this.path,
      "downloadStatus": this.downloadStatus.index,
    };
  }

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      url: json["url"],
      height: json["height"],
      width: json["width"],
      path: json["path"],
      downloadStatus: DownloadStatus.values[json["downloadStatus"]],
    );
  }
}
