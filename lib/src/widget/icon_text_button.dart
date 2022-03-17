import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IconTextButton extends StatelessWidget {
  double? height;
  double? width;
  IconData iconData;
  Color? iconColor;
  double? iconSize;
  Widget text;
  VoidCallback? onPressed;

  IconTextButton({
    Key? key,
    this.height,
    this.width,
    required this.iconData,
    this.iconColor,
    this.iconSize,
    required this.text,
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
            ),
            text,
          ],
        ),
      ),
    );
  }
}
