import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'eh_group_name_selector.dart';

class EHDownloadDialog extends StatefulWidget {
  final String? currentGroup;
  final List<String> candidates;

  const EHDownloadDialog({Key? key, this.currentGroup, required this.candidates}) : super(key: key);

  @override
  State<EHDownloadDialog> createState() => _EHDownloadDialogState();
}

class _EHDownloadDialogState extends State<EHDownloadDialog> {
  late String group;

  bool? downloadOriginalImage = DownloadSetting.downloadOriginalImageByDefault.value;

  @override
  void initState() {
    group = widget.currentGroup ?? 'default'.tr;
    widget.candidates.remove(group);
    widget.candidates.insert(0, group);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('chooseGroup'.tr),
      contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 24),
      actionsPadding: const EdgeInsets.only(left: 24, right: 20, bottom: 12),
      content: _buildBody(),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            if (group.isEmpty) {
              toast('invalid'.tr);
              backRoute();
              return;
            }
            backRoute(result: {'group': group, 'downloadOriginalImage': downloadOriginalImage});
          },
          child: Text('OK'.tr),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SizedBox(
      height: UIConfig.downloadDialogBodyHeight,
      width: UIConfig.downloadDialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EHGroupNameSelector(
            currentGroup: widget.currentGroup ?? 'default'.tr,
            candidates: widget.candidates,
            listener: (g) => group = g,
          ),
          if (downloadOriginalImage != null) _buildDownloadOriginalImageCheckBox().marginOnly(top: 16),
        ],
      ),
    );
  }

  Widget _buildDownloadOriginalImageCheckBox() {
    return SizedBox(
      height: UIConfig.downloadDialogCheckBoxHeight,
      width: UIConfig.downloadDialogWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('downloadOriginalImage'.tr + ' ?', style: const TextStyle(fontSize: UIConfig.groupDialogCheckBoxTextSize)),
          Checkbox(
            value: downloadOriginalImage,
            activeColor: UIConfig.groupDialogCheckBoxColor,
            onChanged: (bool? value) => setState(() => downloadOriginalImage = (value ?? true)),
          ),
        ],
      ),
    );
  }
}
