import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:resizable_widget/resizable_widget.dart';
import 'package:throttling/throttling.dart';
import 'package:window_manager/window_manager.dart';

import '../setting/preference_setting.dart';
import 'jh_service.dart';
import 'log.dart';

WindowService windowService = WindowService();

class WindowService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  bool windowManagerInited = false;

  double windowWidth = 1280;
  double windowHeight = 720;
  bool isMaximized = false;
  bool isFullScreen = false;

  double leftColumnWidthRatio = 1 - 0.618;

  final Debouncing windowResizedDebouncing = Debouncing(duration: const Duration(milliseconds: 300));
  final Debouncing columnResizedDebouncing = Debouncing(duration: const Duration(milliseconds: 300));

  @override
  List<JHLifeCircleBean> get initDependencies => [pathService, log, localConfigService, preferenceSetting];

  @override
  Future<void> doOnInit() async {
    windowWidth = await localConfigService.read(configKey: ConfigEnum.windowWidth).then((value) => value != null ? double.parse(value) : windowWidth);
    windowHeight = await localConfigService.read(configKey: ConfigEnum.windowHeight).then((value) => value != null ? double.parse(value) : windowHeight);
    isMaximized = await localConfigService.read(configKey: ConfigEnum.windowMaximize).then((value) => value != null ? value == 'true' : isMaximized);
    isFullScreen = await localConfigService.read(configKey: ConfigEnum.windowFullScreen).then((value) => value != null ? value == 'true' : isFullScreen);
    leftColumnWidthRatio =
        await localConfigService.read(configKey: ConfigEnum.leftColumnWidthRatio).then((value) => value != null ? double.parse(value) : leftColumnWidthRatio);
    leftColumnWidthRatio = max(0.01, leftColumnWidthRatio);

    if (GetPlatform.isDesktop) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = WindowOptions(
        center: true,
        size: Size(windowWidth, windowHeight),
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'JHenTai',
        titleBarStyle: GetPlatform.isWindows ? TitleBarStyle.hidden : TitleBarStyle.normal,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        if (preferenceSetting.launchInFullScreen.isTrue) {
          await windowManager.setFullScreen(true);
        }
        if (isMaximized) {
          await windowManager.maximize();
        }
        windowManagerInited = true;
      });
    }

    log.info('Init WindowService success');
  }

  @override
  void doOnReady() {}

  void handleColumnResized(List<WidgetSizeInfo> infoList) {
    if (leftColumnWidthRatio == infoList[0].percentage) {
      return;
    }

    columnResizedDebouncing.debounce(() {
      leftColumnWidthRatio = max(0.01, infoList[0].percentage);

      log.info('Resize left column ratio to: $leftColumnWidthRatio');
      localConfigService.write(configKey: ConfigEnum.leftColumnWidthRatio, value: leftColumnWidthRatio.toString());
    });
  }

  void handleWindowResized() {
    windowResizedDebouncing.debounce(() {
      windowWidth = fullScreenWidth;
      windowHeight = screenHeight;

      log.info('Resize window to: $windowWidth x $windowHeight');

      localConfigService.write(configKey: ConfigEnum.windowWidth, value: windowWidth.toString());
      localConfigService.write(configKey: ConfigEnum.windowHeight, value: windowHeight.toString());
    });
  }

  Future<bool> saveMaximizeWindow(bool isMaximized) {
    log.info(isMaximized ? 'Maximized window' : 'Restored window');

    this.isMaximized = isMaximized;
    return localConfigService.write(configKey: ConfigEnum.windowMaximize, value: isMaximized.toString());
  }

  Future<bool> saveFullScreen(bool isFullScreen) {
    log.info(isFullScreen ? 'Enter full screen' : 'Leave full screen');

    this.isFullScreen = isFullScreen;
    return localConfigService.write(configKey: ConfigEnum.windowFullScreen, value: isFullScreen.toString());
  }
}
