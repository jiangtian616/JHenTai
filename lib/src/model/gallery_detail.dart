import 'dart:collection';

import '../database/database.dart';
import 'gallery_comment.dart';
import 'gallery_thumbnail.dart';

class GalleryDetail {
  int ratingCount;
  double realRating;
  String size;
  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  String archivePageUrl;
  LinkedHashMap<String, List<TagData>> fullTags;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;

  GalleryDetail({
    required this.ratingCount,
    required this.realRating,
    required this.size,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.archivePageUrl,
    required this.fullTags,
    required this.comments,
    required this.thumbnails,
  });
}
