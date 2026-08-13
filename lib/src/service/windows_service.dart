import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:path/path.dart' as path;
import 'package:throttling/throttling.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../setting/advanced_setting.dart';
import '../setting/preference_setting.dart';
import '../setting/style_setting.dart';
import 'app_update_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

WindowService windowService = WindowService();

class WindowService
    with JHLifeCircleBeanErrorCatch, WidgetsBindingObserver
    implements JHLifeCircleBean, WindowListener, TrayListener {
  bool windowManagerInited = false;

  /// True while the "stay resident" mode is active: closing the window hides it
  /// and keeps the app (and its LAN sharing server) running in the background.
  bool _residentModeActive = false;

  double windowWidth = 1280;
  double windowHeight = 720;
  bool isMaximized = false;
  bool isFullScreen = false;

  double leftColumnWidthRatio = 1 - 0.618;

  final Debouncing windowResizedDebouncing =
      Debouncing(duration: const Duration(milliseconds: 300));
  final Debouncing columnResizedDebouncing =
      Debouncing(duration: const Duration(milliseconds: 300));

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies
    ..addAll([
      localConfigService,
      preferenceSetting,
      styleSetting,
      appUpdateService,
      advancedSetting,
      pathService
    ]);

  @override
  Future<void> doInitBean() async {
    windowWidth = await localConfigService
        .read(configKey: ConfigEnum.windowWidth)
        .then((value) => value != null ? double.parse(value) : windowWidth);
    windowHeight = await localConfigService
        .read(configKey: ConfigEnum.windowHeight)
        .then((value) => value != null ? double.parse(value) : windowHeight);
    isMaximized = await localConfigService
        .read(configKey: ConfigEnum.windowMaximize)
        .then((value) => value != null ? value == 'true' : isMaximized);
    isFullScreen = await localConfigService
        .read(configKey: ConfigEnum.windowFullScreen)
        .then((value) => value != null ? value == 'true' : isFullScreen);
    leftColumnWidthRatio = await localConfigService
        .read(configKey: ConfigEnum.leftColumnWidthRatio)
        .then((value) =>
            value != null ? double.parse(value) : leftColumnWidthRatio);
    leftColumnWidthRatio = max(0.01, leftColumnWidthRatio);

    if (GetPlatform.isDesktop) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = WindowOptions(
        center: true,
        size: Size(windowWidth, windowHeight),
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'JHenTai',
        titleBarStyle: GetPlatform.isWindows || ThemeConfig.isApple
            ? TitleBarStyle.hidden
            : TitleBarStyle.normal,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        windowManagerInited = true;
        if (GetPlatform.isMacOS && ThemeConfig.isApple) {
          /// Let the sidebar's native material extend beneath the traffic
          /// lights while the Flutter content reaches the top edge.
          await WindowManipulator.makeTitlebarTransparent();
          await WindowManipulator.enableFullSizeContentView();
          await WindowManipulator.setWindowBackgroundColorToClear();
          await _syncMacOSAppearance();
        }
        if (preferenceSetting.launchInFullScreen.isTrue) {
          await windowManager.setFullScreen(true);
        }
        if (isMaximized) {
          await windowManager.maximize();
        }
        if (advancedSetting.lanStayResident.value) {
          unawaited(_applyResidentMode(true));
        }
      });
    }
  }

  @override
  Future<void> doAfterBeanReady() async {
    WidgetsBinding.instance.addObserver(this);
    ever(styleSetting.appleVisualStyle, applyAppleVisualStyle);
    ever(styleSetting.themeMode, (_) => unawaited(_syncMacOSAppearance()));
    ever(advancedSetting.lanStayResident, (enabled) async {
      await _applyResidentMode(enabled);
    });
    if (advancedSetting.lanStayResident.value) {
      await _applyResidentMode(true);
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (styleSetting.themeMode.value == ThemeMode.system) {
      unawaited(_syncMacOSAppearance());
    }
  }

  Future<void> _syncMacOSAppearance() async {
    if (!GetPlatform.isMacOS || !windowManagerInited) {
      return;
    }
    final Brightness brightness = styleSetting.themeMode.value == ThemeMode.system
        ? PlatformDispatcher.instance.platformBrightness
        : styleSetting.currentBrightness();
    await WindowManipulator.overrideMacOSBrightness(
      dark: brightness == Brightness.dark,
    );
  }

  /// Switches the desktop "stay resident" mode on/off. While active, closing
  /// the window hides it (the app and its LAN sharing server keep running) and
  /// a system tray icon restores it; otherwise the window closes normally.
  Future<void> _applyResidentMode(bool enabled) async {
    if (!GetPlatform.isDesktop || !windowManagerInited) {
      return;
    }
    if (enabled && !_residentModeActive) {
      _residentModeActive = true;
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      try {
        trayManager.addListener(this);
        await _setupTray();
      } on Object catch (error, stack) {
        log.warning('Set up system tray failed: $error');
        log.trace(stack);
      }
    } else if (!enabled && _residentModeActive) {
      _residentModeActive = false;
      await windowManager.setPreventClose(false);
      windowManager.removeListener(this);
      try {
        trayManager.removeListener(this);
        await trayManager.destroy();
      } on Object catch (error, stack) {
        log.warning('Destroy system tray failed: $error');
        log.trace(stack);
      }
    }
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon(await _trayIconPath());
    await trayManager.setToolTip('JHenTai');
    await trayManager.setContextMenu(
      Menu(items: [
        MenuItem(key: 'show', label: 'lanResidentShow'.tr),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'lanResidentQuit'.tr),
      ]),
    );
  }

  /// Materializes the bundled tray icon to a real file path, which the native
  /// tray plugin requires.
  Future<String> _trayIconPath() async {
    final File file = File(
      path.join(pathService.tempDir.path, 'jh_tray_icon.png'),
    );
    if (!await file.exists()) {
      final ByteData data =
          await rootBundle.load('assets/icon/JHenTai_512.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  @override
  void onWindowClose() {
    if (_residentModeActive) {
      // Keep the app resident (LAN sharing stays up): hide instead of closing.
      windowManager.hide();
    }
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'quit') {
      exit(0);
    }
  }

  Future<void> applyAppleVisualStyle(bool enabled) async {
    if (!GetPlatform.isMacOS || !windowManagerInited) {
      return;
    }
    await windowManager.setTitleBarStyle(
        enabled ? TitleBarStyle.hidden : TitleBarStyle.normal);
    if (enabled) {
      await WindowManipulator.makeTitlebarTransparent();
      await WindowManipulator.enableFullSizeContentView();
      await WindowManipulator.setWindowBackgroundColorToClear();
    } else {
      await WindowManipulator.makeTitlebarOpaque();
      await WindowManipulator.disableFullSizeContentView();
      await WindowManipulator.setWindowBackgroundColorToDefaultColor();
    }
    await _syncMacOSAppearance();
  }

  void handleDoubleColumnResized(UnmodifiableListView<double> ratios) {
    if (leftColumnWidthRatio == ratios[0]) {
      return;
    }

    columnResizedDebouncing.debounce(() {
      leftColumnWidthRatio = max(0.01, ratios[0]);

      log.info('Resize left column ratio to: $leftColumnWidthRatio');
      localConfigService.write(
          configKey: ConfigEnum.leftColumnWidthRatio,
          value: leftColumnWidthRatio.toString());
    });
  }

  void handleWindowResized() {
    windowResizedDebouncing.debounce(() {
      windowWidth = fullScreenWidth;
      windowHeight = screenHeight;

      log.info('Resize window to: $windowWidth x $windowHeight');

      localConfigService.write(
          configKey: ConfigEnum.windowWidth, value: windowWidth.toString());
      localConfigService.write(
          configKey: ConfigEnum.windowHeight, value: windowHeight.toString());
    });
  }

  Future<int> saveMaximizeWindow(bool isMaximized) {
    log.info(isMaximized ? 'Maximized window' : 'Restored window');

    this.isMaximized = isMaximized;
    return localConfigService.write(
        configKey: ConfigEnum.windowMaximize, value: isMaximized.toString());
  }

  Future<int> saveFullScreen(bool isFullScreen) {
    log.info(isFullScreen ? 'Enter full screen' : 'Leave full screen');

    this.isFullScreen = isFullScreen;
    return localConfigService.write(
        configKey: ConfigEnum.windowFullScreen, value: isFullScreen.toString());
  }
}
