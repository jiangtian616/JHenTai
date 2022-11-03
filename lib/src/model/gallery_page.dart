import 'gallery.dart';

class GalleryPageInfo {
  final String? totalCount;

  final List<Gallery> gallerys;

  final int? prevGid;

  final int? nextGid;

  GalleryPageInfo({
    required this.gallerys,
    this.totalCount,
    this.prevGid,
    this.nextGid,
  });
}
