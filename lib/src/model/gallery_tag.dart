import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/database/database.dart';

enum EHTagStatus { confidence, skepticism, incorrect }

class GalleryTag {
  Color? color;
  Color? backgroundColor;
  TagData tagData;
  EHTagStatus? tagStatus;

  GalleryTag({
    this.color,
    this.backgroundColor,
    required this.tagData,
    this.tagStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'color': color?.value,
      'backgroundColor': backgroundColor?.value,
      'tagData': tagData.toJson(),
      'tagStatus': tagStatus?.index,
    };
  }

  factory GalleryTag.fromJson(Map<String, dynamic> map) {
    return GalleryTag(
      color: map['color'] == null ? null : Color(map['color']),
      backgroundColor: map['backgroundColor'] == null ? null : Color(map['backgroundColor']),
      tagData: TagData.fromJson(map['tagData']),
      tagStatus: map['tagStatus'] == null ? null : EHTagStatus.values[map['tagStatus']],
    );
  }

  @override
  String toString() {
    return 'GalleryTag{color: $color, backgroundColor: $backgroundColor, tagData: $tagData, tagStatus: $tagStatus}';
  }
}
