import 'dart:collection';

import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';

class Gallery {
  int gid;
  String token;
  String title;
  String? japaneseTitle;
  String category;
  GalleryImage cover;
  int? pageCount;
  double rating;
  bool hasRated;
  bool isFavorite;
  int? favoriteTagIndex;
  String? favoriteTagName;
  String galleryUrl;
  LinkedHashMap<String, List<GalleryTag>> tags;
  String? language;
  String? uploader;
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
      pageCount: pageCount!,
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
    this.pageCount,
    required this.rating,
    required this.hasRated,
    required this.isFavorite,
    this.favoriteTagIndex,
    this.favoriteTagName,
    required this.galleryUrl,
    required this.tags,
    this.language,
    this.uploader,
    required this.publishTime,
  });
}
