class GalleryComment {
  int id;
  String? username;
  String score;
  String content;
  String time;
  String? lastEditTime;

  GalleryComment({
    required this.id,
    this.username,
    required this.score,
    required this.content,
    required this.time,
    this.lastEditTime,
  });
}
