class GalleryComment {
  String userName;
  String score;
  String content;
  String time;

  GalleryComment({
    required this.userName,
    required this.score,
    required this.content,
    required this.time,
  });

  @override
  String toString() {
    return 'Comment{userName: $userName, score: $score, content: $content, time: $time}';
  }
}
