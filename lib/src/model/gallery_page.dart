import 'package:jhentai/src/model/gallery_count.dart';

import 'gallery.dart';

enum FavoriteSortOrder { favoritedTime, publishedTime }

class GalleryPageInfo {
  final GalleryCount? totalCount;

  final FavoriteSortOrder? favoriteSortOrder;

  final List<Gallery> galleries;

  final String? prevGid;

  final String? nextGid;

  GalleryPageInfo({
    required this.galleries,
    this.favoriteSortOrder,
    this.totalCount,
    this.prevGid,
    this.nextGid,
  });
}
