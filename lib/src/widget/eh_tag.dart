import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';
import '../utils/search_util.dart';
import 'eh_tag_dialog.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final bool enableTapping;
  final bool forceNewRoute;

  final int? gid;
  final String? token;
  final String? apikey;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
    this.enableTapping = false,
    this.forceNewRoute = false,
    this.gid,
    this.token,
    this.apikey,
  }) : super(key: key);

  @override
  State<EHTag> createState() => _EHTagState();
}

class _EHTagState extends State<EHTag> {
  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: widget.tag.backgroundColor ??
            (widget.addNameSpaceColor
                ? ColorConsts.zhTagNameSpaceColor[widget.tag.tagData.key] ?? ColorConsts.tagNameSpaceColor[widget.tag.tagData.key]!
                : UIConfig.ehTagBackGroundColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
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
      ),
    );

    if (!widget.enableTapping) {
      return child;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _searchTag,
        onSecondaryTap: _showDialog,
        onLongPress: () {
          Feedback.forLongPress(context);
          _showDialog();
        },
        child: child,
      ),
    );
  }

  void _searchTag() {
    newSearch('${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"', widget.forceNewRoute);
  }

  void _showDialog() {
    Get.dialog(EHTagDialog(
      tagData: widget.tag.tagData,
      gid: widget.gid!,
      token: widget.token!,
      apikey: widget.apikey!,
    ));
  }
}
