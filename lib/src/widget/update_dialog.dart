import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;

  const UpdateDialog({Key? key, required this.currentVersion, required this.latestVersion}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('availableUpdate'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ver: $currentVersion -> $latestVersion'),
        ],
      ),
      actions: [
        TextButton(
          child: Text('dismiss'.tr),
          onPressed: () {
            localConfigService.write(configKey: ConfigEnum.dismissVersion, value: latestVersion);
            backRoute();
          },
        ),
        TextButton(
          child: Text('check'.tr + ' ->'),
          onPressed: () {
            backRoute();
            launchUrlString('https://github.com/jiangtian616/JHenTai/releases', mode: LaunchMode.externalApplication);
          },
        )
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
