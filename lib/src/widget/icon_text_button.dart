import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

class IconTextButton extends StatelessWidget {
  final double? height;
  final double? width;
  final Icon icon;
  final Widget text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const IconTextButton({
    Key? key,
    this.height,
    this.width,
    required this.icon,
    required this.text,
    this.onPressed,
    this.onLongPress,
    this.onSecondaryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget button = ThemeConfig.isApple
        ? EHAppleIconButton(
            onPressed: onPressed,
            icon: icon,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.basic,
          )
        : IconButton(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.basic,
            onPressed: onPressed,
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [icon, text],
            ),
          );

    return SizedBox(
      height: height,
      width: width,
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        // Apple style: a glass circular icon button with the label beneath it.
        child: ThemeConfig.isApple
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [button, const SizedBox(height: 2), text],
              )
            : button,
      ),
    );
  }
}
