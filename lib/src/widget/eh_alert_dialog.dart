import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class EHDialog extends StatelessWidget {
  final String title;
  final String? content;
  final bool showCancelButton;

  const EHDialog({
    Key? key,
    required this.title,
    this.content,
    this.showCancelButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassDialog(
        settings: UIConfig.glassDialogSettings(context),
        title: title,
        message: content,
        actions: [
          if (showCancelButton)
            GlassDialogAction(label: 'cancel'.tr, onPressed: backRoute),
          GlassDialogAction(
            label: 'OK'.tr,
            onPressed: () => backRoute(result: true),
            isPrimary: true,
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content!),
      actions: [
        if (showCancelButton) EHAppleTextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        EHAppleTextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: true)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }
}
