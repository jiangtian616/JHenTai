import 'gallery.dart';

class GalleryPageInfo {
  final String? totalCount;

  final List<Gallery> gallerys;

  final String? prevGid;

  final String? nextGid;

  GalleryPageInfo({
    required this.gallerys,
    this.totalCount,
    this.prevGid,
    this.nextGid,
  });
}
