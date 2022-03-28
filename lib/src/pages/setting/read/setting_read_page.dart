import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';

class SettingReadPage extends StatelessWidget {
  const SettingReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('readSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('enablePageTurnAnime'.tr),
              trailing: Switch(
                value: ReadSetting.enablePageTurnAnime.value,
                onChanged: (value) => ReadSetting.saveEnablePageTurnAnime(value),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}

