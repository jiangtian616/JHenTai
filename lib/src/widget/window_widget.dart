import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../service/windows_service.dart';

class WindowWidget extends StatefulWidget {
  final Widget child;

  const WindowWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<WindowWidget> createState() => _WindowWidgetState();
}

class _WindowWidgetState extends State<WindowWidget> {
  final WindowService windowService = Get.find<WindowService>();

  @override
  Widget build(BuildContext context) {
    if (!GetPlatform.isDesktop) {
      return widget.child;
    }

    WindowButtonColors buttonColors = WindowButtonColors(iconNormal: Theme.of(context).appBarTheme.titleTextStyle?.color);

    return WindowBorder(
      width: 0.5,
      color: UIConfig.windowBorderColor,
      child: Column(
        children: [
          ColoredBox(
            color: UIConfig.backGroundColor(context),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                appWindow.startDragging();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MinimizeWindowButton(colors: buttonColors),
                  MaximizeWindowButton(colors: buttonColors, onPressed: windowService.handleMaximizeWindow),
                  CloseWindowButton(colors: buttonColors),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
