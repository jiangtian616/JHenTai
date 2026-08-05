import '../database/database.dart';
import '../service/gallery_download/gallery_download_service.dart';

class GalleryImage {
  String url;
  double? height;
  double? width;

  String? originalImageUrl;
  double? originalImageHeight;
  double? originalImageWidth;

  /// The key used to reload online image(not available for original image)
  String? reloadKey;

  String? path;
  String? imageHash;
  DownloadStatus downloadStatus;

  GalleryImage({
    required this.url,
    this.height,
    this.width,
    this.originalImageUrl,
    this.originalImageHeight,
    this.originalImageWidth,
    this.reloadKey,
    this.imageHash,
    this.path,
    this.downloadStatus = DownloadStatus.none,
  });

  Map<String, dynamic> toJson() {
    return {
      "url": url,
      "height": height,
      "width": width,
      "originalImageUrl": originalImageUrl,
      "originalImageHeight": originalImageHeight,
      "originalImageWidth": originalImageWidth,
      "reloadKey": reloadKey,
      "imageHash": imageHash,
      "path": path,
      "downloadStatus": downloadStatus.index,
    };
  }

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      url: json["url"],
      height: json["height"],
      width: json["width"],
      originalImageUrl: json["originalImageUrl"],
      originalImageHeight: json["originalImageHeight"],
      originalImageWidth: json["originalImageWidth"],
      reloadKey: json["reloadKey"],
      imageHash: json["imageHash"],
      path: json["path"],
      downloadStatus: DownloadStatus.values[json["downloadStatus"]],
    );
  }

  GalleryImage copyWith({
    String? url,
    double? height,
    double? width,
    String? originalImageUrl,
    double? originalImageHeight,
    double? originalImageWidth,
    String? imageHash,
    String? path,
    DownloadStatus? downloadStatus,
  }) {
    return GalleryImage(
      url: url ?? this.url,
      height: height ?? this.height,
      width: width ?? this.width,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      originalImageHeight: originalImageHeight ?? this.originalImageHeight,
      originalImageWidth: originalImageWidth ?? this.originalImageWidth,
      reloadKey: reloadKey ?? this.reloadKey,
      imageHash: imageHash ?? this.imageHash,
      path: path ?? this.path,
      downloadStatus: downloadStatus ?? this.downloadStatus,
    );
  }

  @override
  String toString() {
    return 'GalleryImage{url: $url, height: $height, width: $width, originalImageUrl: $originalImageUrl, originalImageHeight: $originalImageHeight, originalImageWidth: $originalImageWidth, reloadKey: $reloadKey, path: $path, imageHash: $imageHash, downloadStatus: $downloadStatus}';
  }
}

/// Lightweight index of a [GalleryImage], mirroring the DB columns of the `image` table.
/// Always resident in memory for every gallery that has DB rows; the full [GalleryImage]
/// (with runtime-only fields like `reloadKey`, `originalImageUrl`, dimensions) is lazy-loaded
/// into [GalleryDownloadInfo.imagesCache] only when needed.
class GalleryImageIndex {
  final int serialNo;
  final String url;
  String? path;
  DownloadStatus downloadStatus;
  String? imageHash;

  GalleryImageIndex({
    required this.serialNo,
    required this.url,
    this.path,
    required this.downloadStatus,
    this.imageHash,
  });

  factory GalleryImageIndex.fromImageData(ImageData d) {
    return GalleryImageIndex(
      serialNo: d.serialNo,
      url: d.url,
      path: d.path,
      downloadStatus: DownloadStatus.values[d.downloadStatusIndex],
      imageHash: d.imageHash.isEmpty ? null : d.imageHash,
    );
  }

  GalleryImage toGalleryImage() {
    return GalleryImage(
      url: url,
      path: path,
      imageHash: imageHash,
      downloadStatus: downloadStatus,
    );
  }
}
