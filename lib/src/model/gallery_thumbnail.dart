class GalleryThumbnail {
  String href;

  /// when user use MPV, replace it with normal href
  /// https://e-hentai.org/mpv/3114482/05db553d1f/#page1
  String replacedMPVHref(int pageNo) {
    if (originImageHash == null) {
      return href;
    }
    RegExpMatch? match = RegExp(r'(.+?)/mpv/(.+?)/').firstMatch(href);
    if (match == null) {
      return href;
    }

    String prefix = match.group(1)!;
    String gid = match.group(2)!;

    return '$prefix/s/${originImageHash!.substring(0, 10)}/$gid-$pageNo';
  }

  /// displayed when set cookie [datatags = 1]
  /// 4e6f3ee6fd4ea261c11e11d6091b41a9a68503b6
  String? originImageHash;

  /// Large image
  bool isLarge;

  String thumbUrl;
  double? thumbHeight;
  double? thumbWidth;
  double? offSet;

//<editor-fold desc="Data Methods">
  GalleryThumbnail({
    required this.href,
    required this.isLarge,
    required this.thumbUrl,
    this.thumbHeight,
    this.thumbWidth,
    this.offSet,
    this.originImageHash,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryThumbnail &&
          runtimeType == other.runtimeType &&
          href == other.href &&
          isLarge == other.isLarge &&
          thumbUrl == other.thumbUrl &&
          thumbHeight == other.thumbHeight &&
          thumbWidth == other.thumbWidth &&
          offSet == other.offSet &&
          originImageHash == other.originImageHash);

  @override
  int get hashCode =>
      href.hashCode ^ isLarge.hashCode ^ thumbUrl.hashCode ^ thumbHeight.hashCode ^ thumbWidth.hashCode ^ offSet.hashCode ^ originImageHash.hashCode;

  @override
  String toString() {
    return 'GalleryThumbnail{' +
        ' href: $href,' +
        ' isLarge: $isLarge,' +
        ' thumbUrl: $thumbUrl,' +
        ' thumbHeight: $thumbHeight,' +
        ' thumbWidth: $thumbWidth,' +
        ' offSet: $offSet,' +
        ' originImageHash: $originImageHash,' +
        '}';
  }

  GalleryThumbnail copyWith({
    String? href,
    bool? isLarge,
    String? thumbUrl,
    double? thumbHeight,
    double? thumbWidth,
    double? offSet,
    String? originImageHash,
  }) {
    return GalleryThumbnail(
      href: href ?? this.href,
      isLarge: isLarge ?? this.isLarge,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      thumbHeight: thumbHeight ?? this.thumbHeight,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      offSet: offSet ?? this.offSet,
      originImageHash: originImageHash ?? this.originImageHash,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'href': this.href,
      'isLarge': this.isLarge,
      'thumbUrl': this.thumbUrl,
      'thumbHeight': this.thumbHeight,
      'thumbWidth': this.thumbWidth,
      'offSet': this.offSet,
      'originImageHash': this.originImageHash,
    };
  }

  factory GalleryThumbnail.fromMap(Map<String, dynamic> map) {
    return GalleryThumbnail(
      href: map['href'] as String,
      isLarge: map['isLarge'] as bool,
      thumbUrl: map['thumbUrl'] as String,
      thumbHeight: map['thumbHeight'] as double,
      thumbWidth: map['thumbWidth'] as double,
      offSet: map['offSet'] as double,
      originImageHash: map['originImageHash'] as String,
    );
  }
}
