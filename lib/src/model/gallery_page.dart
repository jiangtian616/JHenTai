import 'gallery.dart';

enum FavoriteSortOrder { favoritedTime, publishedTime }

class GalleryPageInfo {
  final String? totalCount;

  final FavoriteSortOrder? favoriteSortOrder;

  final List<Gallery> gallerys;

  final String? prevGid;

  final String? nextGid;

  GalleryPageInfo({
    required this.gallerys,
    this.favoriteSortOrder,
    this.totalCount,
    this.prevGid,
    this.nextGid,
  });
}
