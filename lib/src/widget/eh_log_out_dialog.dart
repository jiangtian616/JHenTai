import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../network/eh_request.dart';
import '../utils/route_util.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('logout'.tr + ' ?'),
      actions: [
        CupertinoDialogAction(child: Text('cancel'.tr), onPressed: backRoute),
        CupertinoDialogAction(
          child: Text('OK'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
          onPressed: () {
            EHRequest.requestLogout();
            backRoute();
          },
        ),
      ],
    );
  }
}
