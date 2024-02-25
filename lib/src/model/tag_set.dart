import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/database/database.dart';

class WatchedTag {
  int tagId;
  TagData tagData;
  bool watched;
  bool hidden;
  Color? backgroundColor;
  int weight;

  WatchedTag({
    required this.tagId,
    required this.tagData,
    required this.watched,
    required this.hidden,
    this.backgroundColor,
    required this.weight,
  });

  WatchedTag copyWith({
    int? tagId,
    TagData? tagData,
    bool? watched,
    bool? hidden,
    Color? backgroundColor,
    int? weight,
  }) {
    return WatchedTag(
      tagId: tagId ?? this.tagId,
      tagData: tagData ?? this.tagData.copyWith(),
      watched: watched ?? this.watched,
      hidden: hidden ?? this.hidden,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      weight: weight ?? this.weight,
    );
  }

  @override
  String toString() {
    return 'TagSet{tagId: $tagId, tagData: $tagData, watched: $watched, hidden: $hidden, backgroundColor: $backgroundColor, weight: $weight}';
  }
}
