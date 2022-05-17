import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:like_button/like_button.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/gallery_comment.dart';
import '../../../network/eh_request.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';

class EHComment extends StatefulWidget {
  final GalleryComment comment;
  final double? height;
  final int? maxLines;
  final bool canTapUrl;

  const EHComment({
    Key? key,
    required this.comment,
    this.height,
    this.maxLines,
    this.canTapUrl = false,
  }) : super(key: key);

  @override
  _EHCommentState createState() => _EHCommentState();
}

class _EHCommentState extends State<EHComment> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Get.theme.brightness == Brightness.light ? Colors.grey.shade200 : Colors.grey.shade800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.comment.userName ?? 'unknownUser'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.comment.userName == null
                        ? Colors.grey.shade600
                        : widget.comment.userName == UserSetting.userName.value
                            ? Get.theme.primaryColorLight
                            : Get.theme.primaryColor,
                  ),
                ),
                Text(
                  widget.comment.time,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (widget.maxLines != null)
              Expanded(
                child: HtmlWidget(
                  _wrapUrlInATag(widget.comment.content),
                  textStyle: const TextStyle(fontSize: 12),
                  factoryBuilder: () => _WidgetFactoryWithTextMaxLine(
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.ellipsis,
                    canTapUrl: false,
                  ),
                ).marginOnly(top: 4),
              ),
            if (widget.maxLines == null)
              HtmlWidget(
                _wrapUrlInATag(widget.comment.content),
                textStyle: const TextStyle(fontSize: 13),
                onTapUrl: _handleTapUrl,
                isSelectable: true,
                customWidgetBuilder: (element) {
                  if (element.localName == 'img') {
                    return Center(
                      child: ExtendedImage.network(element.attributes['src']!).marginSymmetric(vertical: 20),
                    );
                  }
                },
                factoryBuilder: () => _WidgetFactoryWithTextMaxLine(),
              ).marginOnly(top: 2, bottom: 14),
            Row(
              children: [
                if (widget.comment.lastEditTime != null)
                  Text(
                    '${'lastEditedOn'.tr}: ${widget.comment.lastEditTime}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const Expanded(child: SizedBox()),
                if (widget.comment.score.isNotEmpty)
                  LikeButton(
                    size: 18,
                    likeBuilder: (isLiked) => Icon(
                      Icons.thumb_up,
                      size: 18,
                      color: Colors.green.shade800,
                    ),
                    onTap: (isLiked) => _handleVotingComment(widget.comment.id, true),
                  ).marginOnly(right: 14),
                if (widget.comment.score.isNotEmpty)
                  LikeButton(
                    size: 18,
                    likeBuilder: (isLiked) => Icon(
                      Icons.thumb_down,
                      size: 18,
                      color: Colors.red.shade800,
                    ),
                    onTap: (isLiked) => _handleVotingComment(widget.comment.id, false),
                  ).marginOnly(right: 14),
                Text(
                  widget.comment.score.isNotEmpty ? widget.comment.score : 'uploader'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ).paddingOnly(top: 12, bottom: 7, left: 12, right: 12),
      ),
    );
  }

  /// some url link doesn't be wrapped in <a href='xxx'></a>, to help html parse, we manually add it.
  String _wrapUrlInATag(String html) {
    RegExp reg = RegExp(r'(<[^a][^>]*>[^<>]*)(https?:\/\/((\w|=|\?|\.|\/|&|-|#|%|@)+))');
    reg.allMatches(html).map((e) => e.group(0)).toList();
    return html.replaceAllMapped(reg, (Match match) {
      String url = match.group(2)!;
      return match.group(1)! + '''<a href = "$url">$url</a>''';
    });
  }

  Future<bool?> _handleVotingComment(int commentId, bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return null;
    }

    final DetailsPageState detailsPageState = DetailsPageLogic.current!.state;
    Response response;
    try {
      response = await EHRequest.voteComment(
        detailsPageState.gallery!.gid,
        detailsPageState.gallery!.token,
        UserSetting.ipbMemberId.value!,
        detailsPageState.apikey,
        commentId,
        isVotingUp,
      );
    } on DioError catch (e) {
      Log.error('voteCommentFailed'.tr, e.message);
      snack('voteCommentFailed'.tr, e.message);
      return false;
    }

    setState(() {
      int score = jsonDecode(response.toString())['comment_score'];
      widget.comment.score = score >= 0 ? '+' + score.toString() : score.toString();
    });
    return true;
  }

  Future<bool> _handleTapUrl(String url) async {
    if (!widget.canTapUrl) {
      return false;
    }
    if (url.startsWith(EHConsts.EHIndex + '/g') || url.startsWith(EHConsts.EXIndex + '/g')) {
      toNamed(Routes.details, arguments: url, offAllBefore: false);
      return true;
    }
    return await launch(url);
  }
}

class _WidgetFactoryWithTextMaxLine extends WidgetFactory {
  int? maxLines;
  TextOverflow? overflow;
  final bool canTapUrl;

  _WidgetFactoryWithTextMaxLine({
    this.maxLines,
    this.overflow,
    this.canTapUrl = true,
  });

  /// set maxLines and overflow
  @override
  Widget? buildText(BuildMetadata meta, TextStyleHtml tsh, InlineSpan text) {
    if (selectableText && meta.overflow == TextOverflow.clip && text is TextSpan) {
      return SelectableText.rich(
        text,
        maxLines: maxLines ?? (meta.maxLines > 0 ? meta.maxLines : null),
        textAlign: tsh.textAlign ?? TextAlign.start,
        textDirection: tsh.textDirection,
        textScaleFactor: 1.0,
        onSelectionChanged: selectableTextOnChanged,
      );
    }

    return RichText(
      maxLines: maxLines ?? (meta.maxLines > 0 ? meta.maxLines : null),
      overflow: overflow ?? meta.overflow,
      text: text,
      textAlign: tsh.textAlign ?? TextAlign.start,
      textDirection: tsh.textDirection,
    );
  }

  /// if we are at details page, cancel the GestureRecognizer
  @override
  InlineSpan? buildTextSpan({
    List<InlineSpan>? children,
    GestureRecognizer? recognizer,
    TextStyle? style,
    String? text,
  }) {
    if (text?.isEmpty == true) {
      if (children?.isEmpty == true) {
        return null;
      }
      if (children?.length == 1) {
        return children!.first;
      }
    }

    return TextSpan(
      children: children,
      mouseCursor: canTapUrl && recognizer != null ? SystemMouseCursors.click : null,
      recognizer: canTapUrl ? recognizer : null,
      style: style,
      text: text,
    );
  }

  /// don't show image in details page
  @override
  Widget? buildImageWidget(BuildMetadata meta, ImageSource src) {
    return null;
  }
}
