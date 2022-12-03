class GalleryThumbnail {
  String href;

  /// Large image
  bool isLarge;
  String thumbUrl;
  double? thumbHeight;
  double? thumbWidth;
  double? offSet;

//<editor-fold desc="Data Methods">

  GalleryThumbnail({
    required this.href,
    required this.thumbUrl,
    required this.isLarge,
    this.thumbHeight,
    this.thumbWidth,
    this.offSet,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryThumbnail &&
          runtimeType == other.runtimeType &&
          href == other.href &&
          thumbUrl == other.thumbUrl &&
          isLarge == other.isLarge &&
          thumbHeight == other.thumbHeight &&
          thumbWidth == other.thumbWidth &&
          offSet == other.offSet);

  @override
  int get hashCode => href.hashCode ^ thumbUrl.hashCode ^ isLarge.hashCode ^ thumbHeight.hashCode ^ thumbWidth.hashCode ^ offSet.hashCode;

  @override
  String toString() {
    return 'GalleryThumbnail{' +
        ' href: $href,' +
        ' thumbUrl: $thumbUrl,' +
        ' isLarge: $isLarge,' +
        ' thumbHeight: $thumbHeight,' +
        ' thumbWidth: $thumbWidth,' +
        ' offSet: $offSet,' +
        '}';
  }

  GalleryThumbnail copyWith({
    String? href,
    String? thumbUrl,
    bool? isLarge,
    double? thumbHeight,
    double? thumbWidth,
    double? offSet,
  }) {
    return GalleryThumbnail(
      href: href ?? this.href,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      isLarge: isLarge ?? this.isLarge,
      thumbHeight: thumbHeight ?? this.thumbHeight,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      offSet: offSet ?? this.offSet,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'href': href,
      'thumbUrl': thumbUrl,
      'isLarge': isLarge,
      'thumbHeight': thumbHeight,
      'thumbWidth': thumbWidth,
      'offSet': offSet,
    };
  }

  factory GalleryThumbnail.fromMap(Map<String, dynamic> map) {
    return GalleryThumbnail(
      href: map['href'] as String,
      thumbUrl: map['thumbUrl'] as String,
      isLarge: map['isLarge'] as bool,
      thumbHeight: map['thumbHeight'] as double,
      thumbWidth: map['thumbWidth'] as double,
      offSet: map['offSet'] as double,
    );
  }

//</editor-fold>
}
