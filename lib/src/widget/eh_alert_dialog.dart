import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';

class EHAlertDialog extends StatelessWidget {
  final String title;

  const EHAlertDialog({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: true)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }
}
