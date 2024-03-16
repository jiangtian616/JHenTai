import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final ValueChanged<GalleryTag>? onTap;
  final ValueChanged<GalleryTag>? onSecondaryTap;
  final ValueChanged<GalleryTag>? onLongPress;
  final bool showTagStatus;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    required this.showTagStatus,
  }) : super(key: key);

  @override
  State<EHTag> createState() => _EHTagState();
}

class _EHTagState extends State<EHTag> {
  @override
  Widget build(BuildContext context) {
    Widget child = Align(
      /// Assign [widthFactor] so that we can use it in [Wrap] in details page
      widthFactor: 1.0,
      alignment: Alignment.center,
      child: Text(
        (widget.tag.tagData.tagName ?? widget.tag.tagData.key) +
            (widget.tag.voteStatus == EHTagVoteStatus.up
                ? '↑'
                : widget.tag.voteStatus == EHTagVoteStatus.down
                    ? '↓'
                    : ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1,
          color: widget.tag.color ?? (widget.addNameSpaceColor ? ColorConsts.tagNameSpaceTextColor : UIConfig.ehTagTextColor(context)),
        ),
      ),
    );

    if (widget.showTagStatus && widget.tag.tagStatus != EHTagStatus.confidence) {
      child = DottedBorder(
        customPath: (size) {
          return Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width, size.height);
        },
        color: UIConfig.ehTagUnderLineColor(context),
        dashPattern: widget.tag.tagStatus == EHTagStatus.skepticism ? const <double>[3, 4] : const <double>[1, 2],
        padding: EdgeInsets.zero,
        strokeCap: widget.tag.tagStatus == EHTagStatus.skepticism ? StrokeCap.round : StrokeCap.butt,
        child: child,
      );
    }

    child = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: widget.tag.backgroundColor ??
            (widget.addNameSpaceColor
                ? ColorConsts.zhTagNameSpaceColor[widget.tag.tagData.key] ?? ColorConsts.tagNameSpaceColor[widget.tag.tagData.key]!
                : UIConfig.ehTagBackGroundColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );

    if (widget.onTap != null || widget.onSecondaryTap != null || widget.onLongPress != null) {
      child = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap != null ? () => widget.onTap!(widget.tag) : null,
          onSecondaryTap: widget.onSecondaryTap != null ? () => widget.onSecondaryTap!(widget.tag) : null,
          onLongPress: widget.onLongPress != null
              ? () {
                  Feedback.forLongPress(context);
                  widget.onLongPress!(widget.tag);
                }
              : null,
          child: child,
        ),
      );
    }

    return child;
  }
}
