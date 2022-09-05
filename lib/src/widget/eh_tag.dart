import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';
import '../setting/user_setting.dart';
import '../utils/route_util.dart';
import '../utils/search_util.dart';
import '../utils/snack_util.dart';
import 'eh_tag_dialog.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final bool enableTapping;

  final int? gid;
  final String? token;
  final String? apikey;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
    this.enableTapping = false,
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
                : Get.theme.colorScheme.secondaryContainer),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        /// Assign [widthFactor] so that we can use it in [Wrap] in details page
        widthFactor: 1.0,
        alignment: Alignment.center,
        child: Text(
          widget.tag.tagData.tagName ?? widget.tag.tagData.key,
          style: TextStyle(fontSize: 12, height: 1, color: widget.tag.color ?? Get.theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );

    if (!widget.enableTapping) {
      return child;
    }
    return GestureDetector(
      onTap: _searchTag,
      onSecondaryTap: _showDialog,
      onLongPress: () {
        Feedback.forLongPress(context);
        _showDialog();
      },
      child: child,
    );
  }

  void _searchTag() {
    newSearch('${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"');
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
