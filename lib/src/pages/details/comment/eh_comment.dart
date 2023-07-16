import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_comment_score_details_dialog.dart';
import 'package:like_button/like_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../exception/eh_exception.dart';
import '../../../model/gallery_comment.dart';
import '../../../network/eh_request.dart';
import '../../../utils/check_util.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';

class EHComment extends StatefulWidget {
  final GalleryComment comment;
  final bool inDetailPage;
  final bool disableButtons;
  final Function(int commentId)? handleTapUpdateCommentButton;

  const EHComment({
    Key? key,
    required this.comment,
    required this.inDetailPage,
    this.disableButtons = false,
    this.handleTapUpdateCommentButton,
  }) : super(key: key);

  @override
  _EHCommentState createState() => _EHCommentState();
}

class _EHCommentState extends State<EHComment> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EHCommentHeader(
            inDetailPage: widget.inDetailPage,
            username: widget.comment.username,
            commentTime: widget.comment.time,
            fromMe: widget.comment.fromMe,
          ),
          Flexible(
            child: _EHCommentTextBody(inDetailPage: widget.inDetailPage, element: widget.comment.content).paddingOnly(top: 4, bottom: 8),
          ),
          _EHCommentFooter(
            inDetailPage: widget.inDetailPage,
            commentId: widget.comment.id,
            score: widget.comment.score,
            scoreDetails: widget.comment.scoreDetails,
            lastEditTime: widget.comment.lastEditTime,
            fromMe: widget.comment.fromMe,
            disableButtons: widget.disableButtons,
            handleTapUpdateCommentButton: widget.handleTapUpdateCommentButton,
          ),
        ],
      ).paddingOnly(left: 8, right: 8, top: 8, bottom: 6),
    );
  }
}

class _EHCommentHeader extends StatelessWidget {
  final bool inDetailPage;
  final String? username;
  final String commentTime;
  final bool fromMe;

  const _EHCommentHeader({
    Key? key,
    required this.inDetailPage,
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
            fontSize: inDetailPage ? UIConfig.commentAuthorTextSizeInDetailPage : UIConfig.commentAuthorTextSizeInCommentPage,
            fontWeight: FontWeight.bold,
            color: username == null
                ? UIConfig.commentUnknownAuthorTextColor(context)
                : fromMe
                    ? UIConfig.commentOwnAuthorTextColor(context)
                    : UIConfig.commentOtherAuthorTextColor(context),
          ),
        ),
        Text(
          commentTime,
          style: TextStyle(
            fontSize: inDetailPage ? UIConfig.commentTimeTextSizeInDetailPage : UIConfig.commentTimeTextSizeInCommentPage,
            color: UIConfig.commentTimeTextColor(context),
          ),
        ),
      ],
    );
  }
}

class _EHCommentTextBody extends StatelessWidget {
  final bool inDetailPage;
  final dom.Element element;

  const _EHCommentTextBody({
    Key? key,
    required this.inDetailPage,
    required this.element,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget widget = Container(
      alignment: Alignment.topLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: inDetailPage ? UIConfig.commentBodyTextSizeInDetailPage : UIConfig.commentBodyTextSizeInCommentPage,
            color: UIConfig.commentBodyTextColor(context),
            height: 1.5,
          ),
          children: element.nodes.map((tag) => buildTag(context, tag)).toList(),
        ),
        maxLines: inDetailPage ? 5 : null,
        overflow: inDetailPage ? TextOverflow.ellipsis : null,
      ),
    );

    if (!inDetailPage) {
      widget = SelectionArea(child: widget);
    }

    return widget;
  }

  /// Maybe i can rewrite it by `Chain of Responsibility Pattern`
  InlineSpan buildTag(BuildContext context, dom.Node node) {
    /// plain text
    if (node is dom.Text) {
      return _buildText(context, node.text);
    }

    /// unknown node
    if (node is! dom.Element) {
      Log.error('Can not parse html node: $node');
      Log.upload(Exception('Can not parse html node'), extraInfos: {'node': node});
      return TextSpan(text: node.text);
    }

    /// advertisement
    if (node.localName == 'div' && node.attributes['id'] == 'spa') {
      return const TextSpan();
    }

    if (node.localName == 'br') {
      return const TextSpan(text: '\n');
    }

    /// span
    if (node.localName == 'span') {
      return TextSpan(
        style: _parseTextStyle(node),
        children: node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// strong
    if (node.localName == 'strong') {
      return TextSpan(
        style: const TextStyle(fontWeight: FontWeight.bold),
        children: node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// em
    if (node.localName == 'em') {
      return TextSpan(
        style: const TextStyle(fontStyle: FontStyle.italic),
        children: node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// del
    if (node.localName == 'del') {
      return TextSpan(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
        children: node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// image
    if (node.localName == 'img') {
      /// not show image in detail page
      if (inDetailPage) {
        return TextSpan(text: '[${'image'.tr}]  ', style: const TextStyle(color: UIConfig.commentLinkColor));
      }

      return WidgetSpan(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _computeImageMaxWidth(constraints, node)),
              child: ExtendedImage.network(node.attributes['src']!),
            );
          },
        ),
      );
    }

    /// link
    if (node.localName == 'a') {
      return TextSpan(
        text: node.text,
        style: const TextStyle(color: UIConfig.commentLinkColor),
        recognizer: inDetailPage ? null : (TapGestureRecognizer()..onTap = () => _handleTapUrl(node.attributes['href'] ?? node.text)),
        children: node.children.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    Log.error('Can not parse html tag: $node');
    Log.upload(Exception('Can not parse html tag'), extraInfos: {'node': node});
    return TextSpan(text: node.text);
  }

  InlineSpan _buildText(BuildContext context, String text) {
    RegExp reg = RegExp(r'(https?:\/\/((\w|=|\?|\.|\/|&|-|#|%|@|~|\+|:)+))');
    Match? match = reg.firstMatch(text);

    if (match == null) {
      return TextSpan(text: text, style: TextStyle(color: UIConfig.commentBodyTextColor(context)));
    }

    /// some url link doesn't be wrapped in <a href='xxx'></a>, we manually render it as a url.
    if (match.start == 0) {
      return TextSpan(
        text: match.group(0),
        style: const TextStyle(color: UIConfig.commentLinkColor),
        recognizer: inDetailPage ? null : (TapGestureRecognizer()..onTap = () => _handleTapUrl(match.group(0)!)),
        children: [_buildText(context, text.substring(match.end))],
      );
    }

    return TextSpan(
      text: text.substring(0, match.start),
      style: TextStyle(color: UIConfig.commentBodyTextColor(context)),
      children: [_buildText(context, text.substring(match.start))],
    );
  }

  TextStyle? _parseTextStyle(dom.Element node) {
    final style = node.attributes['style'];
    if (style == null) {
      return null;
    }

    final Map<String, String> styleMap = Map.fromEntries(
      style.split(';').map((e) => e.split(':')).where((e) => e.length == 2).map((e) => MapEntry(e[0].trim(), e[1].trim())),
    );

    return TextStyle(
      color: styleMap['color'] == null ? null : Color(int.parse(styleMap['color']!.substring(1), radix: 16) + 0xFF000000),
      fontWeight: styleMap['font-weight'] == 'bold' ? FontWeight.bold : null,
      fontStyle: styleMap['font-style'] == 'italic' ? FontStyle.italic : null,
      decoration: styleMap['text-decoration'] == 'underline' ? TextDecoration.underline : null,
    );
  }

  /// make sure align several images into one line
  double _computeImageMaxWidth(BoxConstraints constraints, dom.Element element) {
    /// wrapped in a <a>
    if (element.parent?.localName == 'a') {
      element = element.parent!;
    }

    int previousImageCount = 0;
    int followingImageCount = 0;
    dom.Element? previousElement = element.previousElementSibling;
    dom.Element? nextElement = element.nextElementSibling;

    while (previousElement != null && _containsImage(previousElement)) {
      previousImageCount++;
      previousElement = previousElement.previousElementSibling;
    }
    while (nextElement != null && _containsImage(nextElement)) {
      followingImageCount++;
      nextElement = nextElement.nextElementSibling;
    }

    /// tolerance = 1
    return constraints.maxWidth / (1 + previousImageCount + followingImageCount) - 1;
  }

  bool _containsImage(dom.Element element) {
    if (element.localName == 'img') {
      return true;
    }

    if (element.children.isEmpty) {
      return false;
    }

    return element.children.any((child) => _containsImage(child));
  }

  Future<bool> _handleTapUrl(String url) async {
    if (url.startsWith(EHConsts.EHIndex + '/g') || url.startsWith(EHConsts.EXIndex + '/g')) {
      toRoute(
        Routes.details,
        arguments: {'gid': parseGalleryUrl2Gid(url), 'galleryUrl': url},
        offAllBefore: false,
      );
      return true;
    }

    return await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

class _EHCommentFooter extends StatefulWidget {
  final bool inDetailPage;
  final int commentId;
  final String? lastEditTime;
  final String score;
  final List<String> scoreDetails;
  final bool fromMe;
  final bool disableButtons;
  final Function(int commentId)? handleTapUpdateCommentButton;

  const _EHCommentFooter({
    Key? key,
    required this.inDetailPage,
    required this.commentId,
    this.lastEditTime,
    required this.score,
    required this.scoreDetails,
    required this.fromMe,
    required this.disableButtons,
    this.handleTapUpdateCommentButton,
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
            style: TextStyle(fontSize: UIConfig.commentLastEditTimeTextSize, color: UIConfig.commentFooterTextColor(context)),
          ),
        const Expanded(child: SizedBox()),

        /// can't vote for uploader or ourselves, and if we have commented, we can't vote for all of the comments
        if (score.isNotEmpty && !widget.fromMe && !widget.disableButtons) ...[
          LikeButton(
            size: widget.inDetailPage ? UIConfig.commentButtonSizeInDetailPage : UIConfig.commentButtonSizeInCommentPage,
            likeBuilder: (_) => Icon(Icons.thumb_up, size: UIConfig.commentButtonSizeInDetailPage, color: UIConfig.commentButtonColor(context)),
            onTap: (_) => _handleVotingComment(true),
          ).marginOnly(right: 18),
          LikeButton(
            size: widget.inDetailPage ? UIConfig.commentButtonSizeInDetailPage : UIConfig.commentButtonSizeInCommentPage,
            likeBuilder: (_) => Icon(Icons.thumb_down, size: UIConfig.commentButtonSizeInDetailPage, color: UIConfig.commentButtonColor(context)),
            onTap: (_) => _handleVotingComment(false),
          ),
        ],

        if (!widget.inDetailPage && widget.fromMe)
          GestureDetector(
            onTap: () => widget.handleTapUpdateCommentButton?.call(widget.commentId),
            child: const Icon(Icons.edit_note, size: UIConfig.commentButtonSizeInCommentPage),
          ),

        GestureDetector(
          onTap: () => score.isEmpty ? null : Get.dialog(EHCommentScoreDetailsDialog(scoreDetails: widget.scoreDetails)),

          /// fix width to align buttons
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36),
            child: Align(
              alignment: Alignment.centerRight,
              child: score.isEmpty
                  ? Text(
                      'uploader'.tr,
                      style: TextStyle(
                        fontSize: widget.inDetailPage ? UIConfig.commentScoreSizeInDetailPage : UIConfig.commentScoreSizeInCommentPage,
                        color: UIConfig.commentFooterTextColor(context),
                      ),
                    )
                  : AnimatedFlipCounter(
                      prefix: score.substring(0, 1),
                      value: int.parse(score.substring(1)),
                      duration: const Duration(milliseconds: 700),
                      textStyle: TextStyle(
                        fontSize: widget.inDetailPage ? UIConfig.commentScoreSizeInDetailPage : UIConfig.commentScoreSizeInCommentPage,
                        color: UIConfig.commentFooterTextColor(context),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _handleVotingComment(bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return null;
    }

    _doVoteComment(isVotingUp);

    return true;
  }

  Future<void> _doVoteComment(bool isVotingUp) async {
    Log.info('Voting comment: ${widget.commentId}, isVotingUp: $isVotingUp');

    final DetailsPageState detailsPageState = DetailsPageLogic.current!.state;
    int? newScore;

    try {
      newScore = await EHRequest.voteComment(
        detailsPageState.gallery!.gid,
        detailsPageState.gallery!.token,
        UserSetting.ipbMemberId.value!,
        detailsPageState.apikey!,
        widget.commentId,
        isVotingUp,
        parser: EHSpiderParser.votingCommentResponse2Score,
      );
    } on DioError catch (e) {
      Log.error('voteCommentFailed'.tr, e.message);
      toast('${'voteCommentFailed'.tr}: ${e.message}');
      return;
    } on EHException catch (e) {
      Log.error('voteCommentFailed'.tr, e.message);
      toast('${'voteCommentFailed'.tr}: ${e.message}');
      return;
    } on CheckException catch (_) {
      /// expired apikey
      await DetailsPageLogic.current?.handleRefresh();
      return _doVoteComment(isVotingUp);
    }

    if (newScore == null) {
      toast('retryHint'.tr);
      return;
    }

    setStateSafely(() {
      score = newScore! >= 0 ? '+' + newScore.toString() : newScore.toString();
    });
  }
}
