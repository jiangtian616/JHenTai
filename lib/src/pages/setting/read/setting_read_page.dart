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
              title: Text('enableImmersiveMode'.tr),
              subtitle: Text('enableImmersiveHint'.tr),
              trailing: Switch(
                value: ReadSetting.enableImmersiveMode.value,
                onChanged: (value) => ReadSetting.saveEnableImmersiveMode(value),
              ),
            ),
            ListTile(
              title: Text('enablePageTurnAnime'.tr),
              trailing: Switch(
                value: ReadSetting.enablePageTurnAnime.value,
                onChanged: (value) => ReadSetting.saveEnablePageTurnAnime(value),
              ),
            ),
            ListTile(
              title: Text('readDirection'.tr),
              trailing: DropdownButton<ReadDirection>(
                value: ReadSetting.readDirection.value,
                elevation: 4,
                onChanged: (ReadDirection? newValue) {
                  ReadSetting.saveReadDirection(newValue!);
                },
                items: [
                  DropdownMenuItem(
                    child: Text('top2bottom'.tr),
                    value: ReadDirection.top2bottom,
                  ),
                  DropdownMenuItem(
                    child: Text('left2right'.tr),
                    value: ReadDirection.left2right,
                  ),
                  DropdownMenuItem(
                    child: Text('right2left'.tr),
                    value: ReadDirection.right2left,
                  ),
                ],
              ),
            ),
            if (ReadSetting.readDirection.value == ReadDirection.top2bottom)
              ListTile(
                title: Text('turnPageMode'.tr),
                subtitle: Text('turnPageModeHint'.tr),
                trailing: DropdownButton<TurnPageMode>(
                  value: ReadSetting.turnPageMode.value,
                  elevation: 4,
                  onChanged: (TurnPageMode? newValue) {
                    ReadSetting.saveTurnPageMode(newValue!);
                  },
                  items: [
                    DropdownMenuItem(
                      child: Text('image'.tr),
                      value: TurnPageMode.image,
                    ),
                    DropdownMenuItem(
                      child: Text('screen'.tr),
                      value: TurnPageMode.screen,
                    ),
                    DropdownMenuItem(
                      child: Text('adaptive'.tr),
                      value: TurnPageMode.adaptive,
                    ),
                  ],
                ),
              ),
            if (ReadSetting.readDirection.value == ReadDirection.top2bottom)
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
            if (ReadSetting.readDirection.value != ReadDirection.top2bottom)
              ListTile(
                title: Text('preloadPageCount'.tr),
                trailing: DropdownButton<int>(
                  value: ReadSetting.preloadPageCount.value,
                  elevation: 4,
                  onChanged: (int? newValue) {
                    ReadSetting.savePreloadPageCount(newValue!);
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
              ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
