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
  String? uploader;
  String publishTime;
  int pageCount;
  String size;
  bool isExpunged;
  double rating;
  LinkedHashMap<String, List<GalleryTag>> tags;
  String? language;

  GalleryMetadata({
    required this.galleryUrl,
    required this.archiveKey,
    required this.title,
    required this.japaneseTitle,
    required this.category,
    required this.cover,
    this.uploader,
    required this.publishTime,
    required this.pageCount,
    required this.size,
    required this.isExpunged,
    required this.rating,
    required this.tags,
    this.language,
  });
}
