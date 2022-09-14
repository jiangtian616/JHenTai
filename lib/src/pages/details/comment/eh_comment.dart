import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/state_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:like_button/like_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../model/gallery_comment.dart';
import '../../../network/eh_request.dart';
import '../../../utils/check_util.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';

class EHComment extends StatefulWidget {
  final GalleryComment comment;
  final int? maxLines;
  final double? bodyHeight;
  final bool disableButtons;

  const EHComment({
    Key? key,
    required this.comment,
    this.maxLines,
    this.bodyHeight,
    this.disableButtons = false,
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
          _EHCommentHeader(
            username: widget.comment.username,
            commentTime: widget.comment.time,
            fromMe: widget.comment.fromMe,
          ),
          _EHCommentTextBody(
            html: widget.comment.content,
            maxLines: widget.maxLines,
            bodyHeight: widget.bodyHeight,
          ).marginOnly(top: 2, bottom: 12),
          if (widget.maxLines != null) const Expanded(child: SizedBox()),
          _EHCommentFooter(
            commentId: widget.comment.id,
            score: widget.comment.score,
            lastEditTime: widget.comment.lastEditTime,
            fromMe: widget.comment.fromMe,
            disableButtons: widget.disableButtons,
          ),
        ],
      ).marginOnly(top: 12, bottom: 7, left: 12, right: 12),
    );
  }
}

class _EHCommentHeader extends StatelessWidget {
  final String? username;
  final String commentTime;
  final bool fromMe;

  const _EHCommentHeader({
    Key? key,
    required this.username,
    required this.commentTime,
    required this.fromMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          (username ?? 'unknownUser'.tr) + (fromMe ? ' (${'you'.tr})' : ''),
          style: TextStyle(
            fontSize: UIConfig.commentAuthorTextSize,
            fontWeight: FontWeight.bold,
            color: username == null
                ? UIConfig.commentUnknownAuthorTextColor
                : fromMe
                    ? UIConfig.commentOwnAuthorTextColor
                    : UIConfig.commentOtherAuthorTextColor,
          ),
        ),
        Text(
          commentTime,
          style: TextStyle(fontSize: UIConfig.commentTimeTextSize, color: UIConfig.commentTimeTextColor),
        ),
      ],
    );
  }
}

class _EHCommentTextBody extends StatelessWidget {
  final String html;
  final int? maxLines;
  final double? bodyHeight;

  const _EHCommentTextBody({
    Key? key,
    required this.html,
    this.maxLines,
    this.bodyHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: bodyHeight,
      child: HtmlWidget(
        maxLines == null ? _wrapUrlInATag(html) : _wrapUrlInATag(html).replaceAll('<br>', ' '),
        textStyle: TextStyle(fontSize: UIConfig.commentBodyTextSize, color: Get.theme.colorScheme.onSecondaryContainer),
        onTapUrl: maxLines == null ? _handleTapUrl : null,
        isSelectable: maxLines == null,
        customWidgetBuilder: (element) {
          /// only show text in details page
          if (maxLines != null &&
              (element.localName != 'div' && element.localName != 'p' && element.localName != 'strong' && element.localName != 'a')) {
            return const SizedBox();
          }

          return null;
        },
        factoryBuilder: () => _WidgetFactory(maxLines: maxLines),
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

  _WidgetFactory({this.maxLines});

  /// set maxLines and overflow
  @override
  Widget? buildText(BuildMetadata meta, TextStyleHtml tsh, InlineSpan text) {
    if (selectableText) {
      return super.buildText(meta, tsh, text);
    }

    return RichText(
      maxLines: maxLines ?? (meta.maxLines > 0 ? meta.maxLines : null),
      overflow: TextOverflow.ellipsis,
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
      mouseCursor: maxLines == null && recognizer != null ? SystemMouseCursors.click : null,
      recognizer: maxLines == null ? recognizer : null,
      style: style?.copyWith(overflow: TextOverflow.ellipsis),
      text: text,
    );
  }

  @override
  Widget? buildImage(BuildMetadata meta, ImageMetadata data) {
    final src = data.sources.isNotEmpty ? data.sources.first : null;
    if (src == null) {
      return null;
    }

    return Center(
      child: ExtendedImage.network(src.url).marginSymmetric(vertical: 20),
    );
  }
}

class _EHCommentFooter extends StatefulWidget {
  final int commentId;
  final String? lastEditTime;
  final String score;
  final bool fromMe;
  final bool disableButtons;

  const _EHCommentFooter({
    Key? key,
    required this.commentId,
    this.lastEditTime,
    required this.score,
    required this.fromMe,
    required this.disableButtons,
  }) : super(key: key);

  @override
  State<_EHCommentFooter> createState() => _EHCommentFooterState();
}

class _EHCommentFooterState extends State<_EHCommentFooter> with LoginRequiredMixin {
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
            style: TextStyle(fontSize: UIConfig.commentLastEditTimeTextSize, color: UIConfig.commentFooterTextColor),
          ),
        const Expanded(child: SizedBox()),

        /// can't vote for uploader or ourselves, and if we have commented, we can't vote for all of the comments
        if (score.isNotEmpty && !widget.fromMe && !widget.disableButtons) ...[
          LikeButton(
            size: UIConfig.commentButtonSize,
            likeBuilder: (_) => Icon(Icons.thumb_up, size: UIConfig.commentButtonSize, color: UIConfig.commentButtonColor),
            onTap: (isLiked) => _handleVotingComment(widget.commentId, true),
          ).marginOnly(right: 18),
          LikeButton(
            size: UIConfig.commentButtonSize,
            likeBuilder: (_) => Icon(Icons.thumb_down, size: UIConfig.commentButtonSize, color: UIConfig.commentButtonColor),
            onTap: (isLiked) => _handleVotingComment(widget.commentId, false),
          ),
        ],

        /// fix width to align buttons
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32),
          child: Align(
            alignment: Alignment.centerRight,
            child: score.isEmpty
                ? Text('uploader'.tr, style: TextStyle(fontSize: UIConfig.commentScoreSize, color: UIConfig.commentFooterTextColor))
                : AnimatedFlipCounter(
                    prefix: score.substring(0, 1),
                    value: int.parse(score.substring(1)),
                    duration: const Duration(milliseconds: 700),
                    textStyle: TextStyle(fontSize: UIConfig.commentScoreSize, color: UIConfig.commentFooterTextColor),
                  ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _handleVotingComment(int commentId, bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
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
      toast('${'voteCommentFailed'.tr}: ${e.message}');
      return;
    } on CheckException catch (_) {
      /// expired apikey
      await DetailsPageLogic.current!.handleRefresh();
      return _doVoteComment(commentId, isVotingUp);
    }


    setStateIfMounted(() {
      score = newScore >= 0 ? '+' + newScore.toString() : newScore.toString();
    });
  }
}
