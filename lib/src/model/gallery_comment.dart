class GalleryComment {
  int id;
  String? userName;
  String score;
  String content;
  String time;
  String? lastEditTime;

  GalleryComment({
    required this.id,
    this.userName,
    required this.score,
    required this.content,
    required this.time,
    this.lastEditTime,
  });
}
