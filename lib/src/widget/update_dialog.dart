import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
          textStyle: TextStyle(color: UIConfig.alertColor(context), fontSize: 16),
          onPressed: () {
            storageService.write(dismissVersion, latestVersion);
            backRoute();
          },
        ),
        CupertinoDialogAction(
          child: Text('check'.tr),
          textStyle: const TextStyle(fontSize: 16),
          onPressed: () {
            backRoute();
            launchUrlString('https://github.com/jiangtian616/JHenTai/releases', mode: LaunchMode.externalApplication);
          },
        )
      ],
    );
  }
}
