import 'dart:collection';

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
  String? newVersionGalleryUrl;
  LinkedHashMap<String, List<GalleryTag>> fullTags;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;
  int thumbnailsPageCount;

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
    this.newVersionGalleryUrl,
    required this.fullTags,
    required this.comments,
    required this.thumbnails,
    required this.thumbnailsPageCount,
  });
}
