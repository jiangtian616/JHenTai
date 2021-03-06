import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher.dart';

import '../service/storage_service.dart';

class UpdateDialog extends StatelessWidget {
  final StorageService storageService = Get.find();

  final String currentVersion;
  final String latestVersion;

  static const String dismissVersion = 'dismissVersion';

  UpdateDialog({
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
          child: Text('${'dismiss'.tr} $latestVersion'),
          textStyle: TextStyle(color: Colors.red.shade400, fontSize: 16),
          onPressed: () {
            storageService.write(dismissVersion, latestVersion);
            back();
          },
        ),
        CupertinoDialogAction(
          child: Text('check'.tr),
          textStyle: TextStyle(fontSize: 16),
          onPressed: () {
            back();
            launch('https://github.com/jiangtian616/JHenTai/releases');
          },
        )
      ],
    );
  }
}
