import 'gallery_hh_archive.dart';

class GalleryHHInfo {
  int? gpCount;
  int? creditCount;
  List<GalleryHHArchive> archives;

  GalleryHHInfo({
    this.gpCount,
    this.creditCount,
    required this.archives,
  });
}
