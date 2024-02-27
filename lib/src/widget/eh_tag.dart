import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';
import '../utils/search_util.dart';
import 'eh_tag_dialog.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final bool enableTapping;
  final bool forceNewRoute;
  final bool showTagStatus;
  final ValueChanged<bool>? onTagVoted;

  final int? gid;
  final String? token;
  final String? apikey;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
    this.enableTapping = false,
    this.forceNewRoute = false,
    required this.showTagStatus,
    this.onTagVoted,
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

    if (widget.enableTapping) {
      child = MouseRegion(
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

    return child;
  }

  void _searchTag() {
    if (PreferenceSetting.tagSearchBehaviour.value == TagSearchBehaviour.inheritAll) {
      return newSearch('${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"', widget.forceNewRoute);
    }

    if (PreferenceSetting.tagSearchBehaviour.value == TagSearchBehaviour.inheritPartially) {
      SearchConfig searchConfig = loadSearchPageConfig() ?? SearchConfig();
      searchConfig.keyword = '${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"';
      searchConfig.language = null;
      searchConfig.includeDoujinshi = true;
      searchConfig.includeManga = true;
      searchConfig.includeArtistCG = true;
      searchConfig.includeGameCg = true;
      searchConfig.includeWestern = true;
      searchConfig.includeNonH = true;
      searchConfig.includeImageSet = true;
      searchConfig.includeCosplay = true;
      searchConfig.includeAsianPorn = true;
      searchConfig.includeMisc = true;
      return newSearchWithConfig(searchConfig, widget.forceNewRoute);
    }

    SearchConfig searchConfig = SearchConfig();
    searchConfig.keyword = '${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"';
    return newSearchWithConfig(searchConfig, widget.forceNewRoute);
  }

  void _showDialog() {
    Get.dialog(EHTagDialog(
      tagData: widget.tag.tagData,
      gid: widget.gid!,
      token: widget.token!,
      apikey: widget.apikey!,
      onTagVoted: widget.onTagVoted,
    ));
  }
}
