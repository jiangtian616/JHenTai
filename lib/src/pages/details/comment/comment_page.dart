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
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';

class CommentPage extends StatefulWidget {
  const CommentPage({Key? key}) : super(key: key);

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  late List<GalleryComment> comments;

  @override
  void initState() {
    comments = Get.arguments;
    super.initState();
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
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          ...comments
              .map(
                (comment) => EHComment(
                  comment: comment,
                  canTapUrl: true,
                ).marginOnly(bottom: 8),
              )
              .toList(),
          const SizedBox(height: 80)
        ],
      ).marginOnly(top: 6, left: 8, right: 8),
    );
  }

  void _showAddCommentDialog() async {
    if (!UserSetting.hasLoggedIn()) {
      Get.snackbar('operationFailed'.tr, 'needLoginToOperate'.tr);
      return;
    }

    bool? success = await Get.dialog(const _SendCommentDialog());

    if (success ?? false) {
      List<GalleryComment> newComments = await EHRequest.requestDetailPage(
        galleryUrl: DetailsPageLogic.currentDetailsPageLogic.state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2Comments,
        useCacheIfAvailable: false,
      );
      setState(() {
        comments = newComments;
      });
      DetailsPageLogic.currentDetailsPageLogic.state.galleryDetails!.comments = newComments;
      DetailsPageLogic.currentDetailsPageLogic.update([bodyId]);
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
      Get.snackbar('failed'.tr, 'commentTooShort'.tr, snackPosition: SnackPosition.TOP);
      return;
    }

    setState(() {
      sendCommentState = LoadingState.loading;
    });

    String? errMsg;
    try {
      errMsg = await EHRequest.requestSendComment(
        galleryUrl: DetailsPageLogic.currentDetailsPageLogic.state.gallery!.galleryUrl,
        content: content,
        parser: EHSpiderParser.sendComment2ErrorMsg,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        Log.error('send comment failed', e.message);
        Get.snackbar('failed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
        setState(() {
          sendCommentState = LoadingState.idle;
        });
        return;
      }
    }

    if (errMsg == null) {
      setState(() {
        sendCommentState = LoadingState.loading;
        Get.back(result: true);
      });
      return;
    }

    setState(() {
      sendCommentState = LoadingState.idle;
    });
    Get.snackbar('failed'.tr, errMsg, snackPosition: SnackPosition.TOP);
    return;
  }
}
