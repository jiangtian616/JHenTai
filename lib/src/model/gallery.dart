import 'dart:collection';

import 'package:jhentai/src/model/gallery_image.dart';

class Gallery {
  int gid;
  String token;
  String title;
  String category;
  GalleryImage cover;
  int pageCount;
  double rating;
  bool hasRated;
  bool isFavorite;
  int? favoriteTagIndex;
  String? favoriteTagName;
  String galleryUrl;
  LinkedHashMap<String, List<String>> tags;
  String? language;
  String uploader;
  String publishTime;

  void addFavorite(int favIndex, String tagName) {
    isFavorite = true;
    favoriteTagIndex = favIndex;
    favoriteTagName = tagName;
  }

  void removeFavorite() {
    isFavorite = false;
    favoriteTagIndex = null;
    favoriteTagName = null;
  }

  Gallery({
    required this.gid,
    required this.token,
    required this.title,
    required this.category,
    required this.cover,
    required this.pageCount,
    required this.rating,
    required this.hasRated,
    required this.isFavorite,
    this.favoriteTagIndex,
    this.favoriteTagName,
    required this.galleryUrl,
    required this.tags,
    this.language,
    required this.uploader,
    required this.publishTime,
  });

  Gallery copyWith({
    int? gid,
    String? token,
    String? title,
    String? category,
    GalleryImage? cover,
    int? pageCount,
    double? rating,
    bool? hasRated,
    bool? isFavorite,
    int? favoriteTagIndex,
    String? favoriteTagName,
    String? galleryUrl,
    LinkedHashMap<String, List<String>>? tags,
    String? language,
    String? uploader,
    String? publishTime,
  }) {
    return Gallery(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      cover: cover ?? this.cover,
      pageCount: pageCount ?? this.pageCount,
      rating: rating ?? this.rating,
      hasRated: hasRated ?? this.hasRated,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteTagIndex: favoriteTagIndex ?? this.favoriteTagIndex,
      favoriteTagName: favoriteTagName ?? this.favoriteTagName,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      uploader: uploader ?? this.uploader,
      publishTime: publishTime ?? this.publishTime,
    );
  }
}
