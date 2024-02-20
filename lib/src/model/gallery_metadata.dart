import 'dart:collection';

import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_url.dart';

class GalleryMetadata {
  GalleryUrl galleryUrl;
  String archiveKey;
  String title;
  String japaneseTitle;
  String category;
  GalleryImage cover;
  int pageCount;
  double rating;
  String language;

  /// may be null if (Disowned)
  String? uploader;
  String publishTime;
  bool isExpunged;
  String size;
  int torrentCount;

  LinkedHashMap<String, List<GalleryTag>> tags;

  GalleryMetadata({
    required this.galleryUrl,
    required this.archiveKey,
    required this.title,
    required this.japaneseTitle,
    required this.category,
    required this.cover,
    required this.pageCount,
    required this.rating,
    required this.language,
    this.uploader,
    required this.publishTime,
    required this.isExpunged,
    required this.size,
    required this.torrentCount,
    required this.tags,
  });
}
