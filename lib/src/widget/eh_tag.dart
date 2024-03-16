import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final ValueChanged<GalleryTag>? onTap;
  final ValueChanged<GalleryTag>? onSecondaryTap;
  final ValueChanged<GalleryTag>? onLongPress;
  final bool showTagStatus;
  final bool inDeleteMode;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.showTagStatus = false,
    this.inDeleteMode = false,
  }) : super(key: key);

  @override
  State<EHTag> createState() => _EHTagState();
}

class _EHTagState extends State<EHTag> with AnimationMixin {
  bool inDeleteMode = false;

  late Animation<double> animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();

    inDeleteMode = widget.inDeleteMode;
  }

  @override
  void didUpdateWidget(covariant EHTag oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.inDeleteMode != widget.inDeleteMode) {
      inDeleteMode = widget.inDeleteMode;
      if (inDeleteMode) {
        controller.play();
      } else {
        controller.playReverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Text(
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
    );

    child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        AnimatedSwitcher(
          duration: UIConfig.ehTagAnimationDuration,
          child: inDeleteMode
              ? Container(
                  child: const Icon(Icons.close, size: 12),
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: UIConfig.ehTagDeleteButtonBackGroundColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : const SizedBox(),
        ),
      ],
    );

    child = Align(
      /// Assign [widthFactor] so that we can use it in [Wrap] in details page
      widthFactor: 1.0,
      alignment: Alignment.center,
      child: child,
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
