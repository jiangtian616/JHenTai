import 'dart:collection';

import 'package:jhentai/src/model/gallery_url.dart';

import '../database/database.dart';
import '../service/archive_download_service.dart';
import '../service/gallery_download_service.dart';
import 'gallery_comment.dart';
import 'gallery_image.dart';
import 'gallery_tag.dart';
import 'gallery_thumbnail.dart';

class GalleryDetail {
  GalleryUrl galleryUrl;
  String rawTitle;
  String? japaneseTitle;
  String category;
  GalleryImage cover;
  int pageCount;

  /// available when we have rated this gallery
  double? rating;

  /// real rating, not the one we rated
  double realRating;
  int ratingCount;
  int? favoriteTagIndex;
  String? favoriteTagName;

  int favoriteCount;
  String language;

  /// null for disowned gallery
  String? uploader;
  String publishTime;
  bool isExpunged;

  /// full tags: tags in Gallery may be incomplete
  LinkedHashMap<String, List<GalleryTag>> tags;

  String size;
  String torrentCount;
  String torrentPageUrl;
  String archivePageUrl;
  GalleryUrl? parentGalleryUrl;
  List<({GalleryUrl galleryUrl, String title, String updateTime})>? childrenGallerys;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;
  int thumbnailsPageCount;

  bool get hasRated => rating != null;

  bool get isFavorite => favoriteTagIndex != null || favoriteTagName != null;

  GalleryUrl? get newVersionGalleryUrl => childrenGallerys?.lastOrNull?.galleryUrl;

  GalleryDetail({
    required this.galleryUrl,
    required this.rawTitle,
    this.japaneseTitle,
    required this.category,
    required this.cover,
    required this.pageCount,
    this.rating,
    required this.realRating,
    required this.ratingCount,
    this.favoriteTagIndex,
    this.favoriteTagName,
    required this.favoriteCount,
    required this.language,
    this.uploader,
    required this.publishTime,
    required this.isExpunged,
    required this.tags,
    required this.size,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.archivePageUrl,
    this.parentGalleryUrl,
    this.childrenGallerys,
    required this.comments,
    required this.thumbnails,
    required this.thumbnailsPageCount,
  });

  GalleryDownloadedData toGalleryDownloadedData({bool downloadOriginalImage = false, String? group}) {
    return GalleryDownloadedData(
      gid: galleryUrl.gid,
      token: galleryUrl.token,
      title: japaneseTitle ?? rawTitle,
      category: category,
      pageCount: pageCount,
      galleryUrl: galleryUrl.url,
      uploader: uploader,
      publishTime: publishTime,
      downloadStatusIndex: DownloadStatus.downloading.index,
      insertTime: DateTime.now().toString(),
      downloadOriginalImage: downloadOriginalImage,
      priority: GalleryDownloadService.defaultDownloadGalleryPriority,
      sortOrder: 0,
      groupName: group,
    );
  }

  ArchiveDownloadedData toArchiveDownloadedData({
    required String archivePageUrl,
    required bool isOriginal,
    required int size,
    required String group,
  }) {
    return ArchiveDownloadedData(
      gid: galleryUrl.gid,
      token: galleryUrl.token,
      title: japaneseTitle ?? rawTitle,
      category: category,
      pageCount: pageCount,
      galleryUrl: galleryUrl.url,
      uploader: uploader,
      size: size,
      coverUrl: cover.url,
      publishTime: publishTime,
      archiveStatusIndex: ArchiveStatus.unlocking.index,
      archivePageUrl: archivePageUrl,
      isOriginal: isOriginal,
      insertTime: DateTime.now().toString(),
      sortOrder: 0,
      groupName: group,
    );
  }
}
