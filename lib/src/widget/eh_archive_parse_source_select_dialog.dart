import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class EHArchiveParseSourceSelectDialog extends StatefulWidget {
  const EHArchiveParseSourceSelectDialog({super.key});

  @override
  State<EHArchiveParseSourceSelectDialog> createState() => _EHArchiveParseSourceSelectDialogState();
}

class _EHArchiveParseSourceSelectDialogState extends State<EHArchiveParseSourceSelectDialog> {
  ArchiveParseSource? _archiveParseSource = ArchiveParseSource.official;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassDialog(
        settings: UIConfig.glassDialogSettings(context),
        title: 'chooseArchiveParseSource'.tr,
        content: SizedBox(
          width: UIConfig.archiveParseSourceSelectDialogWidth,
          child: RadioGroup<ArchiveParseSource>(
            groupValue: _archiveParseSource,
            onChanged: (value) => setState(() => _archiveParseSource = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ArchiveParseSource>(
                  title: Text('official'.tr),
                  value: ArchiveParseSource.official,
                ),
                RadioListTile(
                  title: Text('archiveBot'.tr),
                  value: ArchiveParseSource.bot,
                ),
              ],
            ),
          ),
        ),
        actions: [
          GlassDialogAction(label: 'cancel'.tr, onPressed: backRoute),
          GlassDialogAction(
            label: 'OK'.tr,
            onPressed: () => backRoute(result: _archiveParseSource),
            isPrimary: true,
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text('chooseArchiveParseSource'.tr),
      contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 24),
      actionsPadding: const EdgeInsets.only(left: 24, right: 20, bottom: 12),
      content: SizedBox(
        width: UIConfig.archiveParseSourceSelectDialogWidth,
        child: RadioGroup<ArchiveParseSource>(
          groupValue: _archiveParseSource,
          onChanged: (value) => setState(() => _archiveParseSource = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ArchiveParseSource>(
                title: Text('official'.tr),
                value: ArchiveParseSource.official,
              ),
              RadioListTile(
                title: Text('archiveBot'.tr),
                value: ArchiveParseSource.bot,
              ),
            ],
          ),
        ),
      ),
      actions: [
        EHAppleTextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        EHAppleTextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: _archiveParseSource)),
      ],
    );
  }
}
