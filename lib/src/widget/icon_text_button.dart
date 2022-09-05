import 'package:flutter/material.dart';

class IconTextButton extends StatelessWidget {
  final double? height;
  final double? width;
  final Icon icon;
  final Widget text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  const IconTextButton({
    Key? key,
    this.height,
    this.width,
    required this.icon,
    required this.text,
    this.onPressed,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: IconButton(
          onPressed: onPressed,
          icon: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [icon, text],
          ),
        ),
      ),
    );
  }
}
