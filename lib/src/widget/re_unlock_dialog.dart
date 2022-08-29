import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/route_util.dart';

class ReUnlockDialog extends StatelessWidget {
  const ReUnlockDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('reUnlock'.tr + ' ?'),
      content: Text('reUnlockHint'.tr),
      actions: [
        CupertinoDialogAction(
          child: Text('cancel'.tr),
          onPressed: backRoute,
        ),
        CupertinoDialogAction(
          child: Text('OK'.tr, style: const TextStyle(color: Colors.red)),
          onPressed: () => backRoute(result: true),
        ),
      ],
    );
  }
}
