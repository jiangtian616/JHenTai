import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import 'auto_mode_interval_dialog.dart';

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
              title: Text('showThumbnails'.tr),
              trailing: Switch(
                value: ReadSetting.showThumbnails.value,
                onChanged: (value) => ReadSetting.saveShowThumbnails(value),
              ),
            ),
            ListTile(
              title: Text('showStatusInfo'.tr),
              trailing: Switch(
                value: ReadSetting.showStatusInfo.value,
                onChanged: (value) => ReadSetting.saveShowStatusInfo(value),
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
              title: Text('enableDoubleTapToScaleUp'.tr),
              trailing: Switch(
                value: ReadSetting.enableDoubleTapToScaleUp.value,
                onChanged: (value) => ReadSetting.saveEnableDoubleTapToScaleUp(value),
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
            ListTile(
              title: Text('autoModeInterval'.tr),
              trailing: InkWell(
                onTap: _showAutoModeIntervalDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${ReadSetting.autoModeInterval.value}s', style: const TextStyle(fontSize: 16)),
                    const Icon(Icons.arrow_forward_ios, size: 16).marginOnly(left: 8, right: 4)
                  ],
                ),
              ),
            ),
            if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
              FadeIn(
                key: const Key('autoModeStyle'),
                child: ListTile(
                  title: Text('autoModeStyle'.tr),
                  trailing: DropdownButton<AutoModeStyle>(
                    value: ReadSetting.autoModeStyle.value,
                    elevation: 4,
                    alignment: AlignmentDirectional.centerEnd,
                    onChanged: (AutoModeStyle? newValue) {
                      ReadSetting.saveAutoModeStyle(newValue!);
                    },
                    items: [
                      DropdownMenuItem(
                        child: Text('scroll'.tr),
                        value: AutoModeStyle.scroll,
                      ),
                      DropdownMenuItem(
                        child: Text('turnPage'.tr),
                        value: AutoModeStyle.turnPage,
                      ),
                    ],
                  ),
                ),
              ),
            if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
              FadeIn(
                key: const Key('turnPageMode'),
                child: ListTile(
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
              ),
            if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
              FadeIn(
                key: const Key('preloadDistanceInOnlineMode'),
                child: ListTile(
                  title: Text('preloadDistanceInOnlineMode'.tr),
                  subtitle: Text('needRestart'.tr),
                  trailing: SizedBox(
                    width: 160,
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
              ),
            if (ReadSetting.readDirection.value != ReadDirection.top2bottom && ReadSetting.enableContinuousHorizontalScroll.isFalse)
              FadeIn(
                child: ListTile(
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
              ),
            if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                ReadSetting.enableAutoScaleUp.isFalse &&
                ReadSetting.enableDoubleColumn.isFalse)
              FadeIn(
                child: ListTile(
                  title: Text('continuousScroll'.tr),
                  subtitle: Text('continuousScrollHint'.tr),
                  trailing: Switch(
                    value: ReadSetting.enableContinuousHorizontalScroll.value,
                    onChanged: (value) => ReadSetting.saveEnableContinuousHorizontalScroll(value),
                  ),
                ),
              ),
            if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                ReadSetting.enableContinuousHorizontalScroll.isFalse &&
                ReadSetting.enableAutoScaleUp.isFalse)
              FadeIn(
                child: ListTile(
                  title: Text('doubleColumn'.tr),
                  trailing: Switch(
                    value: ReadSetting.enableDoubleColumn.value,
                    onChanged: (value) => ReadSetting.saveEnableDoubleColumn(value),
                  ),
                ),
              ),
            if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                ReadSetting.enableContinuousHorizontalScroll.isFalse &&
                ReadSetting.enableDoubleColumn.isFalse)
              FadeIn(
                child: ListTile(
                  title: Text('enableAutoScaleUp'.tr),
                  subtitle: Text('enableAutoScaleUpHints'.tr),
                  trailing: Switch(
                    value: ReadSetting.enableAutoScaleUp.value,
                    onChanged: (value) => ReadSetting.saveEnableAutoScaleUp(value),
                  ),
                ),
              ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }

  void _showAutoModeIntervalDialog() async {
    double? interval = await Get.dialog(const AutoModeIntervalDialog());
    if (interval == null) {
      return;
    }

    ReadSetting.saveAutoModeInterval(interval);
  }
}
