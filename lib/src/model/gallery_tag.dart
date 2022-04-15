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
      'color': this.color,
      'backgroundColor': this.backgroundColor,
      'tagData': this.tagData.toJson(),
    };
  }

  factory GalleryTag.fromJson(Map<String, dynamic> map) {
    return GalleryTag(
      color: map['color'],
      backgroundColor: map['backgroundColor'],
      tagData: TagData.fromJson(map['tagData']),
    );
  }
}
