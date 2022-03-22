import 'dart:collection';

import 'gallery_comment.dart';
import 'gallery_thumbnail.dart';

class GalleryDetails {
  int ratingCount;
  double realRating;
  String size;
  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  LinkedHashMap<String, List<String>> fullTags;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;

  GalleryDetails({
    required this.ratingCount,
    required this.realRating,
    required this.size,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.fullTags,
    required this.comments,
    required this.thumbnails,
  });
}
