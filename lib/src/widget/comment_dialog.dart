import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../network/eh_request.dart';
import '../pages/details/details_page_logic.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';
import 'loading_state_indicator.dart';

class CommentDialog extends StatefulWidget {
  const CommentDialog({Key? key}) : super(key: key);

  @override
  CommentDialogState createState() => CommentDialogState();
}

class CommentDialogState extends State<CommentDialog> {
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
        backRoute(result: true);
      });
      return;
    }

    setState(() {
      sendCommentState = LoadingState.idle;
    });
    snack('sendCommentFailed'.tr, errMsg);

    DetailsPageLogic.current?.update();
    return;
  }
}