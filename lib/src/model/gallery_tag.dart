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
}
