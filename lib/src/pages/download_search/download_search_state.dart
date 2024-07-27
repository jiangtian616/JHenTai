import 'dart:async';

import 'package:jhentai/src/database/database.dart';

class DownloadSearchState {
  DownloadSearchConfigTypeEnum searchType = DownloadSearchConfigTypeEnum.simple;
  Completer<void> searchTypeCompleter = Completer();

  List<GallerySearchVO> gallerys = [];
  List<ArchiveSearchVO> archives = [];
}

enum DownloadSearchConfigTypeEnum {
  simple(1, 'simpleSearch'),
  regex(2, 'regexSearch'),
  ;

  final int code;
  final String desc;

  const DownloadSearchConfigTypeEnum(this.code, this.desc);

  static DownloadSearchConfigTypeEnum fromCode(int code) {
    return DownloadSearchConfigTypeEnum.values.firstWhere((e) => e.code == code);
  }
}

class GallerySearchVO {
  int gid;
  String token;
  String title;
  String category;
  int pageCount;
  String galleryUrl;
  String? oldVersionGalleryUrl;
  String? uploader;
  String publishTime;
  String insertTime;
  bool downloadOriginalImage;
  int priority;
  int sortOrder;
  String groupName;
  List<TagData> tags;
  String? tagRefreshTime;

  GallerySearchVO({
    required this.gid,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    this.oldVersionGalleryUrl,
    this.uploader,
    required this.publishTime,
    required this.insertTime,
    required this.downloadOriginalImage,
    required this.priority,
    required this.sortOrder,
    required this.groupName,
    required this.tags,
    this.tagRefreshTime,
  });
}

class ArchiveSearchVO {
  int gid;
  String token;
  String title;
  String category;
  int pageCount;
  String galleryUrl;
  String coverUrl;
  String? uploader;
  int size;
  String publishTime;
  String archivePageUrl;
  String? downloadPageUrl;
  String? downloadUrl;
  bool isOriginal;
  String insertTime;
  int sortOrder;
  String groupName;
  List<TagData> tags;
  String? tagRefreshTime;

  ArchiveSearchVO({
    required this.gid,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    required this.coverUrl,
    this.uploader,
    required this.size,
    required this.publishTime,
    required this.archivePageUrl,
    this.downloadPageUrl,
    this.downloadUrl,
    required this.isOriginal,
    required this.insertTime,
    required this.sortOrder,
    required this.groupName,
    required this.tags,
    this.tagRefreshTime,
  });
}
