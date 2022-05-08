import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import '../../../utils/route_util.dart';

class AutoModeIntervalDialog extends StatefulWidget {
  const AutoModeIntervalDialog({Key? key}) : super(key: key);

  @override
  State<AutoModeIntervalDialog> createState() => _AutoModeIntervalDialogState();
}

class _AutoModeIntervalDialogState extends State<AutoModeIntervalDialog> {
  double interval = ReadSetting.autoModeInterval.value;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      content: SizedBox(
        height: 150,
        child: CupertinoPicker.builder(
          itemExtent: 30,
          onSelectedItemChanged: (index) => interval = (index + 1) * 0.5,
          scrollController: FixedExtentScrollController(initialItem: interval ~/ 0.5 - 1),
          itemBuilder: (BuildContext context, int index) => Center(
            child: Text(
              '${(index + 1) * 0.5} s',
              style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
            ),
          ),
          childCount: 39,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text('cancel'.tr),
          onPressed: () => back(),
        ),
        CupertinoDialogAction(
          child: Text('OK'.tr),
          onPressed: () => back(result: interval),
        ),
      ],
    );
  }
}
