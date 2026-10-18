import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';

class EHGalleryCategoryTag extends StatelessWidget {
  final String category;
  final double? height;
  final double? width;
  final double borderRadius;
  final bool enabled;
  final Color? color;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  const EHGalleryCategoryTag({
    Key? key,
    required this.category,
    this.height,
    this.width,
    this.borderRadius = 4,
    this.enabled = true,
    this.color,
    this.padding = const EdgeInsets.only(top: 3, bottom: 4, left: 2, right: 2),
    this.textStyle = const TextStyle(height: 1, fontSize: 15, color: UIConfig.galleryCategoryTagTextColor),
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      child: Container(
        alignment: Alignment.center,
        height: height,
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: enabled ? color ?? UIConfig.galleryCategoryColor[category] : UIConfig.galleryCategoryTagDisabledBackGroundColor(context),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Text(
          category,
          overflow: TextOverflow.ellipsis,
          style: enabled ? textStyle : textStyle.copyWith(color: UIConfig.galleryCategoryTagDisabledTextColor(context)),
        ),
      ),
    );
  }
}
