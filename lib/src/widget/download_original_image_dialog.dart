import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/route_util.dart';

class DownloadOriginalImageDialog extends StatelessWidget {
  const DownloadOriginalImageDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('downloadOriginalImage'.tr + ' ?'),
      actions: [
        CupertinoDialogAction(
          child: Text('no'.tr),
          onPressed: () => backRoute(result: false),
        ),
        CupertinoDialogAction(
          child: Text('yes'.tr, style: const TextStyle(color: Colors.red)),
          onPressed: () => backRoute(result: true),
        ),
      ],
    );
  }
}
