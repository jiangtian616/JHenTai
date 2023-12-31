import 'dart:collection';

import 'package:jhentai/src/model/gallery_url.dart';

import 'gallery_comment.dart';
import 'gallery_tag.dart';
import 'gallery_thumbnail.dart';

class GalleryDetail {
  String rawTitle;
  String? japaneseTitle;
  int ratingCount;
  double realRating;
  String size;
  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  String archivePageUrl;
  GalleryUrl? parentGalleryUrl;

  List<({GalleryUrl galleryUrl, String title, String updateTime})>? childrenGallerys;

  LinkedHashMap<String, List<GalleryTag>> fullTags;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;
  int thumbnailsPageCount;

  String? get newVersionGalleryUrl => childrenGallerys?.lastOrNull?.galleryUrl.url;

  GalleryDetail({
    required this.rawTitle,
    this.japaneseTitle,
    required this.ratingCount,
    required this.realRating,
    required this.size,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.archivePageUrl,
    this.parentGalleryUrl,
    this.childrenGallerys,
    required this.fullTags,
    required this.comments,
    required this.thumbnails,
    required this.thumbnailsPageCount,
  });
}
