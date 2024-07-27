import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../service/storage_service.dart';

class UpdateDialog extends StatelessWidget {
  final StorageService storageService = Get.find();

  final String currentVersion;
  final String latestVersion;

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
            localConfigService.write(configKey: ConfigEnum.dismissVersion, value: latestVersion);
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
