import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../exception/eh_exception.dart';
import '../network/eh_request.dart';
import '../pages/details/details_page_logic.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';
import 'loading_state_indicator.dart';

enum CommentDialogType { add, update }

class EHCommentDialog extends StatefulWidget {
  final CommentDialogType type;
  final String title;

  final String initText;
  final int? commentId;

  const EHCommentDialog({
    Key? key,
    required this.type,
    required this.title,
    this.initText = '',
    this.commentId,
  }) : super(key: key);

  @override
  EHCommentDialogState createState() => EHCommentDialogState();
}

class EHCommentDialogState extends State<EHCommentDialog> {
  String content = '';
  TextEditingController controller = TextEditingController();
  LoadingState sendCommentState = LoadingState.idle;

  @override
  void initState() {
    super.initState();
    content = widget.initText;
    controller.text = content;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        autofocus: true,
        controller: controller,
        minLines: 1,
        maxLines: 10,
        onChanged: (String text) => content = text,
        decoration: InputDecoration(
          isDense: true,
          alignLabelWithHint: true,
          labelText: 'atLeast3Characters'.tr,
          labelStyle: const TextStyle(fontSize: 14),
        ),
      ),
      actions: [
        if (sendCommentState == LoadingState.loading) const CupertinoActivityIndicator(radius: 10),
        TextButton(child: const Icon(Icons.send), onPressed: _sendComment)
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

    setState(() => sendCommentState = LoadingState.loading);

    String? errMsg;
    try {
      if (widget.type == CommentDialogType.add) {
        errMsg = await EHRequest.requestSendComment(
          galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
          content: content,
          parser: EHSpiderParser.sendComment2ErrorMsg,
        );
      }

      if (widget.type == CommentDialogType.update) {
        errMsg = await EHRequest.requestUpdateComment(
          galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
          commentId: widget.commentId!,
          content: content,
          parser: EHSpiderParser.sendComment2ErrorMsg,
        );
      }
    } on DioError catch (e) {
      if (e.response?.statusCode != 302) {
        Log.error('sendCommentFailed'.tr, e.message);
        snack('sendCommentFailed'.tr, e.message);
        return;
      }
    } on EHException catch (e) {
      Log.error('sendCommentFailed'.tr, e.message);
      snack('sendCommentFailed'.tr, e.message);
      return;
    } finally {
      setState(() => sendCommentState = LoadingState.idle);
    }

    if (errMsg == null) {
      toast('success'.tr);
      backRoute(result: true);
      return;
    }

    snack('sendCommentFailed'.tr, errMsg);
  }
}
