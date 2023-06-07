import 'dart:collection';

import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';

import '../service/archive_download_service.dart';
import '../service/gallery_download_service.dart';

class Gallery {
  int gid;
  String token;
  String title;
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
  bool isExpunged;

  bool hasLocalFilteredTag;

  GalleryDownloadedData toGalleryDownloadedData({bool downloadOriginalImage = false, String? group}) {
    return GalleryDownloadedData(
      gid: gid,
      token: token,
      title: title,
      category: category,
      pageCount: pageCount!,
      galleryUrl: galleryUrl,
      uploader: uploader,
      publishTime: publishTime,
      downloadStatusIndex: DownloadStatus.downloading.index,
      insertTime: DateTime.now().toString(),
      downloadOriginalImage: downloadOriginalImage,
      priority: GalleryDownloadService.defaultDownloadGalleryPriority,
      sortOrder: 0,
      groupName: group,
    );
  }

  ArchiveDownloadedData toArchiveDownloadedData({
    required String archivePageUrl,
    required bool isOriginal,
    required int size,
    required String group,
  }) {
    return ArchiveDownloadedData(
      gid: gid,
      token: token,
      title: title,
      category: category,
      pageCount: pageCount!,
      galleryUrl: galleryUrl,
      uploader: uploader,
      size: size,
      coverUrl: cover.url,
      publishTime: publishTime,
      archiveStatusIndex: ArchiveStatus.unlocking.index,
      archivePageUrl: archivePageUrl,
      isOriginal: isOriginal,
      insertTime: DateTime.now().toString(),
      sortOrder: 0,
      groupName: group,
    );
  }

  Gallery({
    required this.gid,
    required this.token,
    required this.title,
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
    required this.isExpunged,
    this.hasLocalFilteredTag = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'gid': gid,
      'token': token,
      'title': title,
      'category': category,
      'cover': cover.toJson(),
      'pageCount': pageCount,
      'rating': rating,
      'hasRated': hasRated,
      'isFavorite': isFavorite,
      'favoriteTagIndex': favoriteTagIndex,
      'favoriteTagName': favoriteTagName,
      'galleryUrl': galleryUrl,
      'tags': tags,
      'language': language,
      'uploader': uploader,
      'publishTime': publishTime,
      'isExpunged': isExpunged,
      'isFilteredByLocalTag': hasLocalFilteredTag,
    };
  }

  factory Gallery.fromJson(Map<String, dynamic> map) {
    return Gallery(
      gid: map['gid'],
      token: map['token'],
      title: map['title'],
      category: map['category'],
      cover: GalleryImage.fromJson(map['cover']),
      pageCount: map['pageCount'],
      rating: map['rating'],
      hasRated: map['hasRated'],
      isFavorite: map['isFavorite'],
      favoriteTagIndex: map['favoriteTagIndex'],
      favoriteTagName: map['favoriteTagName'],
      galleryUrl: map['galleryUrl'],
      tags: LinkedHashMap.of(
        (map['tags'] as Map).map(
          (key, value) => MapEntry(
            key,
            (value as List).map((e) => GalleryTag.fromJson(e)).toList(),
          ),
        ),
      ),
      language: map['language'],
      uploader: map['uploader'],
      publishTime: map['publishTime'],
      isExpunged: map['isExpunged'] ?? false,
      hasLocalFilteredTag: map['isFilteredByLocalTag'] ?? false,
    );
  }

  @override
  String toString() {
    return 'Gallery{gid: $gid, token: $token, title: $title, category: $category, cover: $cover, pageCount: $pageCount, rating: $rating, hasRated: $hasRated, isFavorite: $isFavorite, favoriteTagIndex: $favoriteTagIndex, favoriteTagName: $favoriteTagName, galleryUrl: $galleryUrl, tags: $tags, language: $language, uploader: $uploader, publishTime: $publishTime, isExpunged: $isExpunged, isFilteredByLocalTag: $hasLocalFilteredTag}';
  }

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
    LinkedHashMap<String, List<GalleryTag>>? tags,
    String? language,
    String? uploader,
    String? publishTime,
    bool? isExpunged,
    bool? isFilteredByLocalTag,
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
      isExpunged: isExpunged ?? this.isExpunged,
      hasLocalFilteredTag: isFilteredByLocalTag ?? this.hasLocalFilteredTag,
    );
  }
}
