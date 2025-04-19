import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/utils/route_util.dart';

class EHArchiveParseSourceSelectDialog extends StatefulWidget {
  const EHArchiveParseSourceSelectDialog({super.key});

  @override
  State<EHArchiveParseSourceSelectDialog> createState() => _EHArchiveParseSourceSelectDialogState();
}

class _EHArchiveParseSourceSelectDialogState extends State<EHArchiveParseSourceSelectDialog> {
  ArchiveParseSource? _archiveParseSource = ArchiveParseSource.official;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('chooseArchiveParseSource'.tr),
      contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 24),
      actionsPadding: const EdgeInsets.only(left: 24, right: 20, bottom: 12),
      content: SizedBox(
        width: UIConfig.archiveParseSourceSelectDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ArchiveParseSource>(
              title: Text('official'.tr),
              value: ArchiveParseSource.official,
              groupValue: _archiveParseSource,
              onChanged: (value) => setState(() => _archiveParseSource = value),
            ),
            RadioListTile(
              title: Text('archiveBot'.tr),
              value: ArchiveParseSource.bot,
              groupValue: _archiveParseSource,
              onChanged: (value) => setState(() => _archiveParseSource = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: _archiveParseSource)),
      ],
    );
  }
}
