import 'dart:collection';

import 'package:jhentai/src/model/gallery_url.dart';

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

  bool get hasRated => rating != null;

  /// real rating, not the one we rated
  double realRating;
  int? favoriteTagIndex;
  String? favoriteTagName;
  String language;

  /// null when in Thumbnail mode / Favorite tab / for disowned gallery
  String? uploader;
  String publishTime;
  bool isExpunged;

  /// full tags: tags in Gallery may be incomplete
  LinkedHashMap<String, List<GalleryTag>> tags;

  int ratingCount;
  String size;
  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  String archivePageUrl;
  GalleryUrl? parentGalleryUrl;
  List<({GalleryUrl galleryUrl, String title, String updateTime})>? childrenGallerys;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;
  int thumbnailsPageCount;

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
    this.favoriteTagIndex,
    this.favoriteTagName,
    required this.language,
    this.uploader,
    required this.publishTime,
    required this.isExpunged,
    required this.tags,
    required this.ratingCount,
    required this.size,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.archivePageUrl,
    this.parentGalleryUrl,
    this.childrenGallerys,
    required this.comments,
    required this.thumbnails,
    required this.thumbnailsPageCount,
  });
}
