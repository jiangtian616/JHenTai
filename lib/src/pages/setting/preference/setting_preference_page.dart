import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';

import '../../../setting/preference_setting.dart';

class SettingPreferencePage extends StatelessWidget {
  const SettingPreferencePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('preferenceSetting'.tr)),
      body: Obx(
        () => SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildShowR18GImageDirectly().center(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowR18GImageDirectly() {
    return ListTile(
      title: Text('showR18GImageDirectly'.tr),
      trailing: Switch(
        value: PreferenceSetting.showR18GImageDirectly.value,
        onChanged: PreferenceSetting.saveShowR18GImageDirectly,
      ),
    );
  }
}
