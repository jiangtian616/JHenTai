import 'package:flutter/material.dart';

import '../consts/color_consts.dart';

class EHTag extends StatelessWidget {
  final String tagName;
  final bool withColor;
  final bool inZh;
  final double borderRadius;
  final double fontSize;
  final double textHeight;
  final EdgeInsetsGeometry padding;

  const EHTag({
    Key? key,
    required this.tagName,
    this.withColor = false,
    this.inZh = false,
    this.borderRadius = 7,
    this.fontSize = 13,
    this.textHeight = 1.3,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        color: withColor
            ? inZh
                ? ColorConsts.zhTagCategoryColor[tagName]
                : ColorConsts.tagCategoryColor[tagName]
            : Colors.grey.shade200,
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tagName,
              style: TextStyle(
                fontSize: fontSize,
                height: textHeight,
                color: Colors.grey.shade800,
              ),
            )
          ],
        ),
      ),
    );
  }
}
