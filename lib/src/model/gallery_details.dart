import 'gallery_comment.dart';
import 'gallery_thumbnail.dart';

class GalleryDetails {
  int ratingCount;
  double realRating;
  String size;
  int favoriteCount;
  String torrentCount;
  String torrentPageUrl;
  List<GalleryComment> comments;
  List<GalleryThumbnail> thumbnails;

  GalleryDetails({
    required this.realRating,
    required this.size,
    required this.ratingCount,
    required this.favoriteCount,
    required this.torrentCount,
    required this.torrentPageUrl,
    required this.comments,
    required this.thumbnails,
  });

  GalleryDetails copyWith({
    double? realRating,
    String? size,
    int? ratingCount,
    int? favoriteCount,
    String? torrentCount,
    String? torrentPageUrl,
    List<GalleryComment>? comments,
    List<GalleryThumbnail>? thumbnails,
  }) {
    return GalleryDetails(
      realRating: realRating ?? this.realRating,
      size: size ?? this.size,
      ratingCount: ratingCount ?? this.ratingCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      torrentCount: torrentCount ?? this.torrentCount,
      torrentPageUrl: torrentPageUrl ?? this.torrentPageUrl,
      comments: comments ?? this.comments,
      thumbnails: thumbnails ?? this.thumbnails,
    );
  }

  @override
  String toString() {
    return 'GalleryDetails{realRating: $realRating, size: $size, ratingCount: $ratingCount, favoriteCount: $favoriteCount, torrentCount: $torrentCount, torrentPageUrl: $torrentPageUrl, comments: $comments, thumbnails: $thumbnails}';
  }
}
