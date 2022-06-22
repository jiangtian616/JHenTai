import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/database/database.dart';

class TagSet {
  int tagId;
  TagData tagData;
  bool watched;
  bool hidden;
  Color? color;
  int weight;

  TagSet({
    required this.tagId,
    required this.tagData,
    required this.watched,
    required this.hidden,
    this.color,
    required this.weight,
  });

  TagSet copyWith({
    int? tagId,
    TagData? tagData,
    bool? watched,
    bool? hidden,
    Color? color,
    int? weight,
  }) {
    return TagSet(
      tagId: tagId ?? this.tagId,
      tagData: tagData ?? this.tagData.copyWith(),
      watched: watched ?? this.watched,
      hidden: hidden ?? this.hidden,
      color: color ?? this.color,
      weight: weight ?? this.weight,
    );
  }

  @override
  String toString() {
    return 'TagSet{tagId: $tagId, tagData: $tagData, watched: $watched, hidden: $hidden, color: $color, weight: $weight}';
  }
}
