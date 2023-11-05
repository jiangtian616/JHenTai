import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../config/ui_config.dart';
import '../service/windows_service.dart';

mixin WindowWidgetMixin<T extends StatefulWidget> on State<T>, WindowListener {
  final WindowService windowService = Get.find<WindowService>();

  final FocusNode focusNode = FocusNode();

  Color? get titleBarColor => null;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
  }

  @override
  void onWindowMaximize() {
    setState(() {
      if (windowService.inited) {
        windowService.saveMaximizeWindow(true);
      }
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      if (windowService.inited) {
        windowService.saveMaximizeWindow(false);
      }
    });
  }

  @override
  void onWindowResize() {
    if (GetPlatform.isLinux) {
      windowService.handleWindowResized();
    }
  }

  @override
  void onWindowResized() {
    windowService.handleWindowResized();
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() {
      windowService.saveFullScreen(true);
    });
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() {
      windowService.saveFullScreen(false);
    });
  }

  Widget buildWindow({required Widget child}) {
    return wrapKeyboardListener(
      child: GetPlatform.isWindows
          ? buildWindowsTitle(child)
          : GetPlatform.isLinux
              ? buildLinuxTitle(child)
              : GetPlatform.isMacOS
                  ? buildMaxOSTitle(child)
                  : child,
    );
  }

  Widget wrapKeyboardListener({required Widget child}) {
    return KeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) async {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          await toggleFullScreen();
        }
      },
      child: child,
    );
  }

  Widget buildWindowsTitle(Widget child) {
    return Column(
      children: [
        ColoredBox(
          color: titleBarColor ?? UIConfig.backGroundColor(context),
          child: windowService.isFullScreen
              ? Container(height: 12, color: titleBarColor ?? UIConfig.backGroundColor(context))
              : Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (_) => windowManager.startDragging(),
                        onDoubleTap: toggleMaximize,
                        child: Container(constraints: const BoxConstraints(minHeight: 32)),
                      ),
                    ),
                    WindowCaptionButton.minimize(brightness: Theme.of(context).brightness, onPressed: toggleMinimize),
                    if (windowService.isMaximized)
                      WindowCaptionButton.unmaximize(brightness: Theme.of(context).brightness, onPressed: windowManager.unmaximize),
                    if (!windowService.isMaximized)
                      WindowCaptionButton.maximize(brightness: Theme.of(context).brightness, onPressed: windowManager.maximize),
                    WindowCaptionButton.close(brightness: Theme.of(context).brightness, onPressed: windowManager.close),
                  ],
                ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget buildLinuxTitle(Widget child) {
    return Column(
      children: [
        Container(height: 8, color: titleBarColor ?? UIConfig.backGroundColor(context)),
        Expanded(child: child),
      ],
    );
  }

  Widget buildMaxOSTitle(Widget child) {
    return Column(
      children: [
        Container(height: 8, color: titleBarColor ?? UIConfig.backGroundColor(context)),
        Expanded(child: child),
      ],
    );
  }

  Future<void> toggleFullScreen() async {
    bool isFullScreen = await windowManager.isFullScreen();
    if (isFullScreen) {
      windowManager.setFullScreen(false);
    } else {
      windowManager.setFullScreen(true);
    }
  }

  Future<void> toggleMaximize() async {
    bool isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      windowManager.restore();
    } else {
      windowManager.minimize();
    }
  }

  Future<void> toggleMinimize() async {
    bool isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      windowManager.restore();
    } else {
      windowManager.minimize();
    }
  }
}
