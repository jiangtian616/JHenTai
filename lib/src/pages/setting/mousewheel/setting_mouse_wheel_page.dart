import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';

import '../../../utils/toast_util.dart';
import '../eh/tagsets/tag_sets_page.dart';

class SettingMouseWheelPage extends StatelessWidget {
  const SettingMouseWheelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('mouseWheelSetting'.tr)),
      body: Obx(() {
        TextEditingController wheelScrollSpeedController = TextEditingController(text: MouseSetting.wheelScrollSpeed.value.toString());

        return ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            ListTile(
              title: Text('wheelScrollSpeed'.tr),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: wheelScrollSpeedController,
                      decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d|\.')), NumberRangeTextInputFormatter(minValue: 0)],
                      onSubmitted: (_) {
                        double? value = double.tryParse(wheelScrollSpeedController.value.text);
                        if (value == null) {
                          return;
                        }
                        MouseSetting.saveWheelScrollSpeed(value);
                        toast('saveSuccess'.tr);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: UIConfig.resumePauseButtonColor(context)),
                    onPressed: () {
                      double? value = double.tryParse(wheelScrollSpeedController.value.text);
                      if (value == null) {
                        return;
                      }
                      MouseSetting.saveWheelScrollSpeed(value);
                      toast('saveSuccess'.tr);
                    },
                  ),
                ],
              ),
            ),
          ],
        ).withListTileTheme(context);
      }),
    );
  }
}
