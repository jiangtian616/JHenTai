import 'gallery_thumbnail.dart';

class DetailPageInfo {
  final int imageNoFrom;
  final int imageNoTo;
  final int imageCount;
  final int currentPageNo;
  final int pageCount;
  final List<GalleryThumbnail> thumbnails;

  const DetailPageInfo({
    required this.imageNoFrom,
    required this.imageNoTo,
    required this.imageCount,
    required this.currentPageNo,
    required this.pageCount,
    required this.thumbnails,
  });

  /// 20 40 50 100 200 400
  int get thumbnailsCountPerPage => currentPageNo != pageCount
      ? thumbnails.length
      : pageCount != 1
          ? (imageNoFrom - 1) ~/ currentPageNo
          : [20, 40, 50, 100, 200, 400].firstWhere((number) => number >= imageCount);
}
