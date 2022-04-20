import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return SimpleDialog(
      title: Text('availableUpdate'.tr),
      titleTextStyle: Get.theme.dialogTheme.titleTextStyle?.copyWith(fontSize: 18),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0),
      children: [
        Text('${'LatestVersion'.tr}: $latestVersion'),
        Text('${'CurrentVersion'.tr}: $latestVersion').marginOnly(top: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => launch('https://github.com/jiangtian616/JHenTai/releases'),
              child: Text('checkNow'.tr),
            ),
          ],
        ),
      ],
    );
  }
}
