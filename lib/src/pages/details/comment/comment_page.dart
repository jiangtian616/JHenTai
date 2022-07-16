import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/widget/eh_comment.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';

class CommentPage extends StatefulWidget {
  const CommentPage({Key? key}) : super(key: key);

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  late List<GalleryComment> comments;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    comments = Get.arguments;
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('allComments'.tr),
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _showAddCommentDialog,
        child: const Icon(Icons.add, size: 28),
      ),
      body: EHWheelSpeedController(
        scrollController: _scrollController,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          controller: _scrollController,
          children: [
            ...comments
                .map(
                  (comment) => EHComment(
                    comment: comment,
                    canTapUrl: true,
                    showVotingButtons: comments.every((comment) => comment.userName != UserSetting.userName.value),
                  ).marginOnly(bottom: 8),
                )
                .toList(),
            const SizedBox(height: 80)
          ],
        ).marginOnly(top: 6, left: 8, right: 8),
      ),
    );
  }

  void _showAddCommentDialog() async {
    if (!UserSetting.hasLoggedIn()) {
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return;
    }

    bool? success = await Get.dialog(const _SendCommentDialog());

    if (success ?? false) {
      List<GalleryComment> newComments = await EHRequest.requestDetailPage(
        galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2Comments,
        useCacheIfAvailable: false,
      );
      setState(() {
        comments = newComments;
      });
      DetailsPageLogic.current!.state.galleryDetails!.comments = newComments;
      DetailsPageLogic.current!.update([bodyId]);
    }
  }
}

class _SendCommentDialog extends StatefulWidget {
  const _SendCommentDialog({Key? key}) : super(key: key);

  @override
  _SendCommentDialogState createState() => _SendCommentDialogState();
}

class _SendCommentDialogState extends State<_SendCommentDialog> {
  String content = '';
  LoadingState sendCommentState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: const EdgeInsets.fromLTRB(0.0, 12.0, 24.0, 16.0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('newComment'.tr),
          Icon(Icons.chat, color: Theme.of(context).primaryColor, size: 26),
        ],
      ),
      children: [
        CupertinoTextFormFieldRow(
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          style: const TextStyle(fontSize: 14),
          onChanged: (content) => this.content = content,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LoadingStateIndicator(
              loadingState: sendCommentState,
              idleWidget: InkWell(
                onTap: _sendComment,
                child: Icon(
                  Icons.send,
                  color: Colors.green.shade600,
                ),
              ),
              errorWidgetSameWithIdle: true,
            )
          ],
        ),
      ],
    );
  }

  Future<void> _sendComment() async {
    if (content.length <= 2) {
      snack('failed'.tr, 'commentTooShort'.tr);
      return;
    }

    setState(() {
      sendCommentState = LoadingState.loading;
    });

    String? errMsg;
    try {
      errMsg = await EHRequest.requestSendComment(
        galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
        content: content,
        parser: EHSpiderParser.sendComment2ErrorMsg,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        Log.error('sendCommentFailed'.tr, e.message);
        snack('sendCommentFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
        setState(() {
          sendCommentState = LoadingState.idle;
        });
        return;
      }
    }

    if (errMsg == null) {
      setState(() {
        sendCommentState = LoadingState.loading;
        back(result: true);
      });
      return;
    }

    setState(() {
      sendCommentState = LoadingState.idle;
    });
    snack('sendCommentFailed'.tr, errMsg);

    DetailsPageLogic.current?.update([bodyId]);
    return;
  }
}
