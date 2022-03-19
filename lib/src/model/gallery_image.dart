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

//<editor-fold desc="Data Methods">

  GalleryImage({
    required this.url,
    required this.height,
    required this.width,
    this.path,
    this.downloadStatus = DownloadStatus.none,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryImage &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          height == other.height &&
          width == other.width &&
          path == other.path &&
          downloadStatus == other.downloadStatus);

  @override
  int get hashCode => url.hashCode ^ height.hashCode ^ width.hashCode ^ path.hashCode ^ downloadStatus.hashCode;

  @override
  String toString() {
    return 'GalleryImage{' +
        ' url: $url,' +
        ' height: $height,' +
        ' width: $width,' +
        ' path: $path,' +
        ' downloadStatus: $downloadStatus,' +
        '}';
  }

  GalleryImage copyWith({
    String? url,
    double? height,
    double? width,
    String? path,
    DownloadStatus? downloadStatus,
  }) {
    return GalleryImage(
      url: url ?? this.url,
      height: height ?? this.height,
      width: width ?? this.width,
      path: path ?? this.path,
      downloadStatus: downloadStatus ?? this.downloadStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': this.url,
      'height': this.height,
      'width': this.width,
      'path': this.path,
      'downloadStatus': this.downloadStatus,
    };
  }

  factory GalleryImage.fromMap(Map<String, dynamic> map) {
    return GalleryImage(
      url: map['url'] as String,
      height: map['height'] as double,
      width: map['width'] as double,
      path: map['path'] as String,
      downloadStatus: map['downloadStatus'] as DownloadStatus,
    );
  }

//</editor-fold>
}
