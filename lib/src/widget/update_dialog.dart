import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;

  const UpdateDialog({Key? key, required this.currentVersion, required this.latestVersion}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassDialog(
        settings: UIConfig.glassDialogSettings(context),
        title: 'availableUpdate'.tr,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('${'CurrentVersion'.tr}:'), const SizedBox(height: 6), Text('${'LatestVersion'.tr}:')],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(currentVersion), const SizedBox(height: 6), Text(latestVersion)],
              ),
            ),
          ],
        ),
        actions: [
          GlassDialogAction(
            label: 'dismiss'.tr,
            onPressed: () {
              localConfigService.write(configKey: ConfigEnum.dismissVersion, value: latestVersion);
              backRoute();
            },
          ),
          GlassDialogAction(
            label: 'check'.tr + ' ->',
            onPressed: () {
              backRoute();
              launchUrlString('https://github.com/jiangtian616/JHenTai/releases', mode: LaunchMode.externalApplication);
            },
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text('availableUpdate'.tr),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('${'CurrentVersion'.tr}:'), const SizedBox(height: 6), Text('${'LatestVersion'.tr}:')],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(currentVersion), const SizedBox(height: 6), Text(latestVersion)],
            ),
          ),
        ],
      ),
      actions: [
        EHAppleTextButton(
          child: Text('dismiss'.tr),
          onPressed: () {
            localConfigService.write(configKey: ConfigEnum.dismissVersion, value: latestVersion);
            backRoute();
          },
        ),
        EHAppleTextButton(
          child: Text('check'.tr + ' ->'),
          onPressed: () {
            backRoute();
            launchUrlString('https://github.com/jiangtian616/JHenTai/releases', mode: LaunchMode.externalApplication);
          },
        )
      ],
      actionsPadding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 12),
    );
  }
}
