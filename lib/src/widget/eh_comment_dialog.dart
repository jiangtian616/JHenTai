import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../network/eh_request.dart';
import '../pages/details/details_page_logic.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';
import 'loading_state_indicator.dart';

class EHCommentDialog extends StatefulWidget {
  const EHCommentDialog({Key? key}) : super(key: key);

  @override
  EHCommentDialogState createState() => EHCommentDialogState();
}

class EHCommentDialogState extends State<EHCommentDialog> {
  String content = '';
  LoadingState sendCommentState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('newComment'.tr),
      content: TextField(
        autofocus: true,
        minLines: 1,
        maxLines: 10,
        onChanged: (String text) => content = text,
        decoration: InputDecoration(
          isDense: true,
          alignLabelWithHint: true,
          labelText: 'atLeast3Characters'.tr,
          labelStyle: const TextStyle(fontSize: 14),
          suffix: SizedBox(
            height: 16,
            width: 16,
            child: LoadingStateIndicator(
              indicatorRadius: 8,
              loadingState: sendCommentState,
              idleWidget: const SizedBox(),
              errorWidgetSameWithIdle: true,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(child: const Icon(Icons.send), onPressed: _sendComment),
      ],
    );
  }

  Future<void> _sendComment() async {
    if (content.length <= 2) {
      toast('commentTooShort'.tr);
      return;
    }

    if (sendCommentState == LoadingState.loading) {
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
        return;
      }
    } finally {
      setState(() {
        sendCommentState = LoadingState.idle;
      });
    }

    if (errMsg == null) {
      toast('success'.tr);
      backRoute(result: true);
      return;
    }

    snack('sendCommentFailed'.tr, errMsg);
  }
}
