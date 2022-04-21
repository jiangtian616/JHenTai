import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;

  const UpdateDialog({
    Key? key,
    required this.currentVersion,
    required this.latestVersion,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('availableUpdate'.tr),
      content: Column(
        children: [
          Text('${'LatestVersion'.tr}: $latestVersion'),
          Text('${'CurrentVersion'.tr}: $currentVersion'),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          child: Text('cancel'.tr),
          onPressed: back,
        ),
        CupertinoDialogAction(
          child: Text('checkNow'.tr),
          onPressed: () {
            back();
            launch('https://github.com/jiangtian616/JHenTai/releases');
          },
        )
      ],
    );
  }
}
