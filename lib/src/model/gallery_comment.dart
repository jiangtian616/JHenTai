import 'package:html/dom.dart';

class GalleryComment {
  int id;
  String? username;
  int? userId;
  String score;
  List<String> scoreDetails;
  Element content;
  String time;
  String? lastEditTime;
  bool fromMe;
  bool votedUp;
  bool votedDown;

  GalleryComment({
    required this.id,
    this.username,
    this.userId,
    required this.score,
    required this.scoreDetails,
    required this.content,
    required this.time,
    this.lastEditTime,
    required this.fromMe,
    required this.votedUp,
    required this.votedDown,
  });

  @override
  String toString() {
    return 'GalleryComment{id: $id, username: $username, userId: $userId, score: $score, scoreDetails: $scoreDetails, content: $content, time: $time, lastEditTime: $lastEditTime, fromMe: $fromMe, votedUp: $votedUp, votedDown: $votedDown}';
  }
}
