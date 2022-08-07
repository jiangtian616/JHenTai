import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../network/eh_request.dart';
import '../utils/route_util.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('logout'.tr + ' ?'),
      actions: [
        CupertinoDialogAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
        CupertinoDialogAction(
          child: Text('OK'.tr, style: const TextStyle(color: Colors.red)),
          onPressed: () {
            EHRequest.requestLogout();
            untilRoute(predicate: (route) => !Get.isDialogOpen!);
          },
        ),
      ],
    );
  }
}