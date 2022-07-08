import 'package:flutter/material.dart';
import 'package:get/get.dart';

class IconTextButton extends StatelessWidget {
  double? height;
  double? width;
  IconData iconData;
  Color? iconColor;
  double iconSize;
  Widget text;
  double offset;
  VoidCallback? onPressed;

  IconTextButton({
    Key? key,
    this.height,
    this.width,
    required this.iconData,
    this.iconColor,
    this.iconSize = 24.0,
    required this.text,
    this.offset = 0.0,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: TextButton(
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              iconData,
              color: iconColor,
              size: iconSize,
            ).marginOnly(bottom: offset),
            text,
          ],
        ),
      ),
    );
  }
}
