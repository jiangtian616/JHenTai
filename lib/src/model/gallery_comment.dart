class GalleryComment {
  int id;
  String? username;
  String score;
  String content;
  String time;
  String? lastEditTime;
  bool fromMe;

  GalleryComment({
    required this.id,
    this.username,
    required this.score,
    required this.content,
    required this.time,
    this.lastEditTime,
    required this.fromMe,
  });
}
