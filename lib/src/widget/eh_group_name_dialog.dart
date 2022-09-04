import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

enum EHGroupNameDialogType { update, insert }

class EHGroupNameDialog extends StatefulWidget {
  final EHGroupNameDialogType type;
  final String? currentGroup;
  final List<String> candidates;

  const EHGroupNameDialog({Key? key, required this.type, this.currentGroup, required this.candidates}) : super(key: key);

  @override
  State<EHGroupNameDialog> createState() => _EHGroupNameDialogState();
}

class _EHGroupNameDialogState extends State<EHGroupNameDialog> {
  TextEditingController textEditingController = TextEditingController();
  bool? downloadOriginalImage = DownloadSetting.downloadOriginalImageByDefault.value;

  @override
  void initState() {
    textEditingController.value = TextEditingValue(text: widget.currentGroup ?? 'default'.tr);
    widget.candidates.remove(textEditingController.value.text);
    widget.candidates.insert(0, textEditingController.value.text);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text(widget.type == EHGroupNameDialogType.update ? 'changeGroup'.tr : 'chooseGroup'.tr)),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.candidates.isNotEmpty) _buildChips(),
          _buildTextField(),
          if (downloadOriginalImage != null) _buildDownloadOriginalImageCheckBox().marginOnly(top: 16),
        ],
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            if (textEditingController.value.text.isEmpty) {
              toast('invalid'.tr);
              backRoute();
              return;
            }
            backRoute(result: {
              'group': textEditingController.value.text,
              'downloadOriginalImage': downloadOriginalImage,
            });
          },
          child: Text('OK'.tr),
        ),
      ],
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: GlobalConfig.groupDialogHeight,
      width: GlobalConfig.groupDialogWidth,
      child: Center(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: widget.candidates.length,
          itemBuilder: _chipBuilder,
        ),
      ),
    );
  }

  Widget _chipBuilder(_, int index) {
    return ChoiceChip(
      label: Text(widget.candidates[index]),
      labelStyle: const TextStyle(fontSize: GlobalConfig.groupDialogChipTextSize, height: 1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 3),
      selected: textEditingController.value.text == widget.candidates[index],
      onSelected: (bool value) {
        setState(() => textEditingController.value = TextEditingValue(text: widget.candidates[index]));
      },
      side: BorderSide.none,
      backgroundColor: GlobalConfig.groupDialogChipColor,
    ).marginOnly(right: 4);
  }

  Widget _buildTextField() {
    return SizedBox(
      height: GlobalConfig.groupDialogHeight,
      width: GlobalConfig.groupDialogWidth,
      child: Center(
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            alignLabelWithHint: true,
            labelText: 'groupName'.tr,
            labelStyle: const TextStyle(fontSize: GlobalConfig.groupDialogTextFieldLabelTextSize),
          ),
          style: const TextStyle(fontSize: GlobalConfig.groupDialogTextFieldTextSize),
          controller: textEditingController,
        ),
      ),
    );
  }

  Widget _buildDownloadOriginalImageCheckBox() {
    return SizedBox(
      height: GlobalConfig.groupDialogCheckBoxHeight,
      width: GlobalConfig.groupDialogWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('downloadOriginalImage'.tr + ' ?', style: const TextStyle(fontSize: GlobalConfig.groupDialogCheckBoxTextSize)),
          Checkbox(
            value: downloadOriginalImage,
            activeColor: GlobalConfig.groupDialogCheckBoxColor,
            onChanged: (bool? value) => setState(() => downloadOriginalImage = (value ?? true)),
          ),
        ],
      ),
    );
  }
}
