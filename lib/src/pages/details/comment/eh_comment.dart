import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:like_button/like_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../model/gallery_comment.dart';
import '../../../network/eh_request.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';

class EHComment extends StatefulWidget {
  final GalleryComment comment;
  final int? maxLines;
  final bool canTapUrl;
  final bool isSelectable;
  final bool showVotingButtons;

  const EHComment({
    Key? key,
    required this.comment,
    this.maxLines,
    required this.canTapUrl,
    required this.isSelectable,
    this.showVotingButtons = true,
  }) : super(key: key);

  @override
  _EHCommentState createState() => _EHCommentState();
}

class _EHCommentState extends State<EHComment> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        children: [
          _EHCommentHeader(username: widget.comment.username, commentTime: widget.comment.time),
          _EHCommentTextBody(
            html: widget.comment.content,
            maxLines: widget.maxLines,
            canTapUrl: widget.canTapUrl,
            isSelectable: widget.isSelectable,
          ).marginOnly(top: 2, bottom: 16),
          if (widget.maxLines != null) const Expanded(child: SizedBox()),
          _EHCommentFooter(
            commentId: widget.comment.id,
            score: widget.comment.score,
            lastEditTime: widget.comment.lastEditTime,
            showVotingButtons: widget.showVotingButtons,
          ),
        ],
      ).marginOnly(top: 12, bottom: 7, left: 12, right: 12),
    );
  }
}

class _EHCommentHeader extends StatelessWidget {
  final String? username;
  final String commentTime;

  const _EHCommentHeader({Key? key, required this.username, required this.commentTime}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          username ?? 'unknownUser'.tr,
          style: TextStyle(
            fontSize: GlobalConfig.commentAuthorTextSize,
            fontWeight: FontWeight.bold,
            color: username == null
                ? GlobalConfig.commentUnknownAuthorTextColor
                : username == UserSetting.userName.value
                    ? GlobalConfig.commentOwnAuthorTextColor
                    : GlobalConfig.commentOtherAuthorTextColor,
          ),
        ),
        Text(
          commentTime,
          style: TextStyle(fontSize: GlobalConfig.commentTimeTextSize, color: GlobalConfig.commentTimeTextColor),
        ),
      ],
    );
  }
}

class _EHCommentTextBody extends StatelessWidget {
  final String html;
  final bool canTapUrl;
  final bool isSelectable;
  final int? maxLines;

  const _EHCommentTextBody({
    Key? key,
    required this.html,
    required this.canTapUrl,
    required this.isSelectable,
    this.maxLines,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      _wrapUrlInATag(html),
      textStyle: const TextStyle(fontSize: GlobalConfig.commentBodyTextSize),
      onTapUrl: canTapUrl ? _handleTapUrl : null,
      isSelectable: isSelectable,
      customWidgetBuilder: (element) {
        if (element.localName != 'img') {
          return null;
        }
        return Center(
          child: ExtendedImage.network(element.attributes['src']!).marginSymmetric(vertical: 20),
        );
      },
      factoryBuilder: () => _WidgetFactory(
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        canTapUrl: canTapUrl,
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

  Future<bool> _handleTapUrl(String url) async {
    if (url.startsWith(EHConsts.EHIndex + '/g') || url.startsWith(EHConsts.EXIndex + '/g')) {
      toRoute(Routes.details, arguments: {'galleryUrl': url}, offAllBefore: false);
      return true;
    }

    return await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

class _WidgetFactory extends WidgetFactory {
  int? maxLines;
  TextOverflow? overflow;
  final bool canTapUrl;

  _WidgetFactory({
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
      style: style?.copyWith(overflow: TextOverflow.ellipsis),
      text: text,
    );
  }

  @override
  Widget? buildImageWidget(BuildMetadata meta, ImageSource src) {
    /// Don't show image in details page
    if (maxLines != null) {
      return null;
    }

    return super.buildImageWidget(meta, src);
  }
}

class _EHCommentFooter extends StatefulWidget {
  final int commentId;
  final String? lastEditTime;
  final String score;
  final bool showVotingButtons;

  const _EHCommentFooter({
    Key? key,
    required this.commentId,
    this.lastEditTime,
    required this.score,
    required this.showVotingButtons,
  }) : super(key: key);

  @override
  State<_EHCommentFooter> createState() => _EHCommentFooterState();
}

class _EHCommentFooterState extends State<_EHCommentFooter> {
  late String score;

  @override
  void initState() {
    score = widget.score;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.lastEditTime?.isNotEmpty ?? false)
          Text(
            '${'lastEditedOn'.tr}: ${widget.lastEditTime}',
            style: TextStyle(fontSize: GlobalConfig.commentLastEditTimeTextSize, color: GlobalConfig.commentFooterTextColor),
          ),
        const Expanded(child: SizedBox()),
        if (widget.showVotingButtons) ...[
          LikeButton(
            size: GlobalConfig.commentButtonSize,
            likeBuilder: (isLiked) => Icon(Icons.thumb_up, size: GlobalConfig.commentButtonSize, color: GlobalConfig.commentButtonColor),
            onTap: (isLiked) => _handleVotingComment(widget.commentId, true),
          ).marginOnly(right: 18),
          LikeButton(
            size: GlobalConfig.commentButtonSize,
            likeBuilder: (isLiked) => Icon(Icons.thumb_down, size: GlobalConfig.commentButtonSize, color: GlobalConfig.commentButtonColor),
            onTap: (isLiked) => _handleVotingComment(widget.commentId, false),
          ),
        ],
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              score.isNotEmpty ? score : 'uploader'.tr,
              style: TextStyle(fontSize: GlobalConfig.commentScoreSize, color: GlobalConfig.commentFooterTextColor),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _handleVotingComment(int commentId, bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return null;
    }

    _doVoteComment(commentId, isVotingUp);

    return true;
  }

  Future<void> _doVoteComment(int commentId, bool isVotingUp) async {
    Log.info('Voting comment: $commentId, isVotingUp: $isVotingUp');

    final DetailsPageState detailsPageState = DetailsPageLogic.current!.state;
    int newScore;
    try {
      newScore = await EHRequest.voteComment(
        detailsPageState.gallery!.gid,
        detailsPageState.gallery!.token,
        UserSetting.ipbMemberId.value!,
        detailsPageState.apikey,
        commentId,
        isVotingUp,
        parser: EHSpiderParser.votingCommentResponse2Score,
      );
    } on DioError catch (e) {
      Log.error('voteCommentFailed'.tr, e.message);
      snack('voteCommentFailed'.tr, e.message);
      return;
    }

    setState(() {
      score = newScore >= 0 ? '+' + newScore.toString() : newScore.toString();
    });
  }
}
