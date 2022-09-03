import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WindowsApp extends StatelessWidget {
  final Widget child;

  const WindowsApp({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!GetPlatform.isDesktop) {
      return child;
    }

    WindowButtonColors buttonColors = WindowButtonColors(iconNormal: Theme.of(context).appBarTheme.titleTextStyle?.color);

    return WindowBorder(
      width: 0.5,
      color: Colors.black,
      child: Column(
        children: [
          ColoredBox(
            color: Get.theme.colorScheme.background,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => appWindow.startDragging(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MinimizeWindowButton(colors: buttonColors),
                  MaximizeWindowButton(colors: buttonColors),
                  CloseWindowButton(colors: buttonColors),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}