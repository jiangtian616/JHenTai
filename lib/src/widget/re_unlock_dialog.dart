import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../config/ui_config.dart';
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
          child: Text('OK'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
          onPressed: () => backRoute(result: true),
        ),
      ],
    );
  }
}
