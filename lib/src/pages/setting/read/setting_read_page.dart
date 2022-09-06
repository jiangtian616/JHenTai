import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/read_setting.dart';

import 'auto_mode_interval_dialog.dart';

class SettingReadPage extends StatelessWidget {
  const SettingReadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('readSetting'.tr)),
      body: Obx(
        () => SafeArea(
          child: ListView(
            itemExtent: 64,
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildEnableImmersiveMode().center(),
              _buildShowThumbnails().center(),
              _buildShowStatusInfo().center(),
              _buildEnablePageTurnAnime().center(),
              _buildEnableDoubleTapToScaleUp().center(),
              _buildReadDirection().center(),
              if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
                _buildPreloadDistanceInOnlineMode().fadeIn(const Key('preloadDistanceInOnlineMode')).center(),
              if (ReadSetting.readDirection.value != ReadDirection.top2bottom && ReadSetting.enableContinuousHorizontalScroll.isFalse)
                _buildPreloadPageCount().fadeIn(const Key('preloadPageCount')).center(),
              if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                  ReadSetting.enableAutoScaleUp.isFalse &&
                  ReadSetting.enableDoubleColumn.isFalse)
                _buildContinuousScroll().fadeIn(const Key('continuousScroll')).center(),
              if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                  ReadSetting.enableContinuousHorizontalScroll.isFalse &&
                  ReadSetting.enableAutoScaleUp.isFalse)
                _buildDoubleColumn().fadeIn(const Key('doubleColumn')).center(),
              if (ReadSetting.readDirection.value != ReadDirection.top2bottom &&
                  ReadSetting.enableContinuousHorizontalScroll.isFalse &&
                  ReadSetting.enableDoubleColumn.isFalse)
                _buildEnableAutoScaleUp().fadeIn(const Key('enableAutoScaleUp')).center(),
              _buildAutoModeInterval().center(),
              if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
                _buildAutoModeStyle().fadeIn(const Key('autoModeStyle')).center(),
              if (ReadSetting.readDirection.value == ReadDirection.top2bottom || ReadSetting.enableContinuousHorizontalScroll.isTrue)
                _buildTurnPageMode().fadeIn(const Key('turnPageMode')).center(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnableImmersiveMode() {
    return ListTile(
      title: Text('enableImmersiveMode'.tr),
      subtitle: Text('enableImmersiveHint'.tr),
      trailing: Switch(value: ReadSetting.enableImmersiveMode.value, onChanged: ReadSetting.saveEnableImmersiveMode),
    );
  }

  Widget _buildShowThumbnails() {
    return ListTile(
      title: Text('showThumbnails'.tr),
      trailing: Switch(value: ReadSetting.showThumbnails.value, onChanged: ReadSetting.saveShowThumbnails),
    );
  }

  Widget _buildShowStatusInfo() {
    return ListTile(
      title: Text('showStatusInfo'.tr),
      trailing: Switch(value: ReadSetting.showStatusInfo.value, onChanged: ReadSetting.saveShowStatusInfo),
    );
  }

  Widget _buildEnablePageTurnAnime() {
    return ListTile(
      title: Text('enablePageTurnAnime'.tr),
      trailing: Switch(value: ReadSetting.enablePageTurnAnime.value, onChanged: ReadSetting.saveEnablePageTurnAnime),
    );
  }

  Widget _buildEnableDoubleTapToScaleUp() {
    return ListTile(
      title: Text('enableDoubleTapToScaleUp'.tr),
      trailing: Switch(value: ReadSetting.enableDoubleTapToScaleUp.value, onChanged: ReadSetting.saveEnableDoubleTapToScaleUp),
    );
  }

  Widget _buildReadDirection() {
    return ListTile(
      title: Text('readDirection'.tr),
      trailing: DropdownButton<ReadDirection>(
        value: ReadSetting.readDirection.value,
        elevation: 4,
        onChanged: (ReadDirection? newValue) => ReadSetting.saveReadDirection(newValue!),
        items: [
          DropdownMenuItem(child: Text('top2bottom'.tr), value: ReadDirection.top2bottom),
          DropdownMenuItem(child: Text('left2right'.tr), value: ReadDirection.left2right),
          DropdownMenuItem(child: Text('right2left'.tr), value: ReadDirection.right2left),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildPreloadDistanceInOnlineMode() {
    return ListTile(
      title: Text('preloadDistanceInOnlineMode'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildPreloadPageCount() {
    return ListTile(
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
      ).marginOnly(right: 12),
    );
  }

  Widget _buildContinuousScroll() {
    return ListTile(
      title: Text('continuousScroll'.tr),
      subtitle: Text('continuousScrollHint'.tr),
      trailing: Switch(value: ReadSetting.enableContinuousHorizontalScroll.value, onChanged: ReadSetting.saveEnableContinuousHorizontalScroll),
    );
  }

  Widget _buildDoubleColumn() {
    return ListTile(
      title: Text('doubleColumn'.tr),
      trailing: Switch(value: ReadSetting.enableDoubleColumn.value, onChanged: ReadSetting.saveEnableDoubleColumn),
    );
  }

  Widget _buildEnableAutoScaleUp() {
    return ListTile(
      title: Text('enableAutoScaleUp'.tr),
      subtitle: Text('enableAutoScaleUpHints'.tr),
      trailing: Switch(value: ReadSetting.enableAutoScaleUp.value, onChanged: ReadSetting.saveEnableAutoScaleUp),
    );
  }

  Widget _buildAutoModeInterval() {
    return ListTile(
      title: Text('autoModeInterval'.tr),
      onTap: () => Get.dialog(const AutoModeIntervalDialog()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${ReadSetting.autoModeInterval.value}s'),
          const Icon(Icons.keyboard_arrow_right),
        ],
      ).marginOnly(right: 4),
    );
  }

  Widget _buildAutoModeStyle() {
    return ListTile(
      title: Text('autoModeStyle'.tr),
      trailing: DropdownButton<AutoModeStyle>(
        value: ReadSetting.autoModeStyle.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (AutoModeStyle? newValue) => ReadSetting.saveAutoModeStyle(newValue!),
        items: [
          DropdownMenuItem(child: Text('scroll'.tr), value: AutoModeStyle.scroll),
          DropdownMenuItem(child: Text('turnPage'.tr), value: AutoModeStyle.turnPage),
        ],
      ).marginOnly(right: 12),
    );
  }

  Widget _buildTurnPageMode() {
    return ListTile(
      title: Text('turnPageMode'.tr),
      subtitle: Text('turnPageModeHint'.tr),
      trailing: DropdownButton<TurnPageMode>(
        value: ReadSetting.turnPageMode.value,
        elevation: 4,
        onChanged: (TurnPageMode? newValue) => ReadSetting.saveTurnPageMode(newValue!),
        items: [
          DropdownMenuItem(child: Text('image'.tr), value: TurnPageMode.image),
          DropdownMenuItem(child: Text('screen'.tr), value: TurnPageMode.screen),
          DropdownMenuItem(child: Text('adaptive'.tr), value: TurnPageMode.adaptive),
        ],
      ).marginOnly(right: 12),
    );
  }
}
