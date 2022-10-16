import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/database/database.dart';

class GalleryTag {
  Color? color;
  Color? backgroundColor;
  TagData tagData;

  GalleryTag({
    this.color,
    this.backgroundColor,
    required this.tagData,
  });

  Map<String, dynamic> toJson() {
    return {
      'color': color?.value,
      'backgroundColor': backgroundColor?.value,
      'tagData': tagData.toJson(),
    };
  }

  factory GalleryTag.fromJson(Map<String, dynamic> map) {
    return GalleryTag(
      color: map['color'] == null ? null : Color(map['color']),
      backgroundColor: map['backgroundColor'] == null ? null : Color(map['backgroundColor']),
      tagData: TagData.fromJson(map['tagData']),
    );
  }

  @override
  String toString() {
    return 'GalleryTag{color: $color, backgroundColor: $backgroundColor, tagData: $tagData}';
  }
}
