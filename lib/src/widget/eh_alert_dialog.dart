import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';

class EHDialog extends StatelessWidget {
  final String title;
  final String? content;
  final bool showCancelButton;

  const EHDialog({
    Key? key,
    required this.title,
    this.content,
    this.showCancelButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content!),
      actions: [
        if (showCancelButton) TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: true)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }
}
