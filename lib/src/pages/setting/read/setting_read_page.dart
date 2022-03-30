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
            ListTile(
              title: Text('preloadDistanceInOnlineMode'.tr),
              subtitle: Text('needRestart'.tr),
              trailing: SizedBox(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<int>(
                      value: ReadSetting.preloadDistance.value,
                      elevation: 4,
                      onChanged: (int? newValue) {
                        ReadSetting.savePreloadDistance(newValue!);
                      },
                      items: const [
                        DropdownMenuItem(
                          child: Text('0'),
                          value: 0,
                        ),
                        DropdownMenuItem(
                          child: Text('1'),
                          value: 1,
                        ),
                        DropdownMenuItem(
                          child: Text('2'),
                          value: 2,
                        ),
                        DropdownMenuItem(
                          child: Text('3'),
                          value: 3,
                        ),
                        DropdownMenuItem(
                          child: Text('5'),
                          value: 5,
                        ),
                        DropdownMenuItem(
                          child: Text('10'),
                          value: 10,
                        ),
                      ],
                    ),
                    Text('ScreenHeight'.tr).marginSymmetric(horizontal: 12),
                  ],
                ),
              ),
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
