import 'dart:collection';

import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';

class Gallery {
  int gid;
  String token;
  String title;
  String? japaneseTitle;
  String category;
  GalleryImage cover;
  int pageCount;
  double rating;
  bool hasRated;
  bool isFavorite;
  int? favoriteTagIndex;
  String? favoriteTagName;
  String galleryUrl;
  LinkedHashMap<String, List<TagData>> tags;
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

  GalleryDownloadedData toGalleryDownloadedData() {
    return GalleryDownloadedData(
      gid: gid,
      token: token,
      title: title,
      category: category,
      pageCount: pageCount,
      galleryUrl: galleryUrl,
      uploader: uploader,
      publishTime: publishTime,
      downloadStatusIndex: DownloadStatus.downloading.index
    );
  }

  Gallery({
    required this.gid,
    required this.token,
    required this.title,
    this.japaneseTitle,
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
    String? japaneseTitle,
    String? category,
    GalleryImage? cover,
    int? pageCount,
    double? rating,
    bool? hasRated,
    bool? isFavorite,
    int? favoriteTagIndex,
    String? favoriteTagName,
    String? galleryUrl,
    LinkedHashMap<String, List<TagData>>? tags,
    String? language,
    String? uploader,
    String? publishTime,
  }) {
    return Gallery(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      japaneseTitle: japaneseTitle ?? this.japaneseTitle,
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

  Map<String, dynamic> toJson() {
    return {
      "gid": this.gid,
      "token": this.token,
      "title": this.title,
      "japaneseTitle": this.japaneseTitle,
      "category": this.category,
      "cover": this.cover,
      "pageCount": this.pageCount,
      "rating": this.rating,
      "hasRated": this.hasRated,
      "isFavorite": this.isFavorite,
      "favoriteTagIndex": this.favoriteTagIndex,
      "favoriteTagName": this.favoriteTagName,
      "galleryUrl": this.galleryUrl,
      "tags": this.tags,
      "language": this.language,
      "uploader": this.uploader,
      "publishTime": this.publishTime,
    };
  }

  factory Gallery.fromJson(Map<String, dynamic> json) {
    return Gallery(
      gid: int.parse(json["gid"]),
      token: json["token"],
      title: json["title"],
      japaneseTitle: json["japaneseTitle"],
      category: json["category"],
      cover: GalleryImage.fromJson(json["cover"]),
      pageCount: int.parse(json["pageCount"]),
      rating: double.parse(json["rating"]),
      hasRated: json["hasRated"].toLowerCase() == 'true',
      isFavorite: json["isFavorite"].toLowerCase() == 'true',
      favoriteTagIndex: int.parse(json["favoriteTagIndex"]),
      favoriteTagName: json["favoriteTagName"],
      galleryUrl: json["galleryUrl"],
      tags: LinkedHashMap<String, List<TagData>>.from(json["tags"]),
      language: json["language"],
      uploader: json["uploader"],
      publishTime: json["publishTime"],
    );
  }
//
}
