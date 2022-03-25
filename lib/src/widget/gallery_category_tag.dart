import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/consts/color_consts.dart';

class GalleryCategoryTag extends StatelessWidget {
  final String category;
  double? height;
  double? width;
  double borderRadius;
  bool enabled;
  final EdgeInsets padding;
  final TextStyle textStyle;
  VoidCallback? onTap;

  GalleryCategoryTag({
    Key? key,
    required this.category,
    this.height,
    this.width,
    this.borderRadius = 4,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
    this.textStyle = const TextStyle(height: 1, fontSize: 15, color: Colors.white),
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          height: height,
          width: width,
          padding: padding,
          color: enabled ? ColorConsts.galleryCategoryColor[category] : Colors.grey.shade300,
          child: Text(category, style: enabled ? textStyle : textStyle.copyWith(color: Colors.white54)),
        ),
      ),
    );
  }
}
