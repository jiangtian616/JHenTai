enum ImageStatus {
  none,
  downloading,
  downloaded,
}

class GalleryImage {
  String url;
  double height;
  double width;

  String? path;
  ImageStatus status;

  GalleryImage({
    required this.url,
    required this.height,
    required this.width,
    this.path,
    this.status = ImageStatus.none,
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
          status == other.status);

  @override
  int get hashCode => url.hashCode ^ height.hashCode ^ width.hashCode ^ path.hashCode ^ status.hashCode;

  @override
  String toString() {
    return 'GalleryImage{' +
        ' url: $url,' +
        ' height: $height,' +
        ' width: $width,' +
        ' path: $path,' +
        ' status: $status,' +
        '}';
  }

  GalleryImage copyWith({
    String? url,
    double? height,
    double? width,
    String? path,
    ImageStatus? status,
  }) {
    return GalleryImage(
      url: url ?? this.url,
      height: height ?? this.height,
      width: width ?? this.width,
      path: path ?? this.path,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': this.url,
      'height': this.height,
      'width': this.width,
      'path': this.path,
      'status': this.status,
    };
  }

  factory GalleryImage.fromMap(Map<String, dynamic> map) {
    return GalleryImage(
      url: map['url'] as String,
      height: map['height'] as double,
      width: map['width'] as double,
      path: map['path'] as String,
      status: map['status'] as ImageStatus,
    );
  }
}
