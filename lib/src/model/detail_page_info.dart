import 'gallery_thumbnail.dart';

class DetailPageInfo {
  final int rangeIndexFrom;
  final int rangeIndexTo;
  final int imageCount;
  final int currentPageNo;
  final List<GalleryThumbnail> thumbnails;

  const DetailPageInfo({
    required this.rangeIndexFrom,
    required this.rangeIndexTo,
    required this.imageCount,
    required this.currentPageNo,
    required this.thumbnails,
  });
  
  int get thumbnailsCountPerPage => thumbnails.length;
}
