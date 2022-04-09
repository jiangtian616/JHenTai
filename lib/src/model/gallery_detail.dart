import 'dart:collection';

import 'gallery_comment.dart';
import 'gallery_tag.dart';
import 'gallery_thumbnail.dart';

class GalleryDetail {
  int ratingCount;
  double realRating;
  String size;
  int pageCount;

  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  String archivePageUrl;
  LinkedHashMap<String, List<GalleryTag>> fullTags;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;

  GalleryDetail({
    required this.ratingCount,
    required this.realRating,
    required this.size,
    required this.pageCount,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.archivePageUrl,
    required this.fullTags,
    required this.comments,
    required this.thumbnails,
  });
}
