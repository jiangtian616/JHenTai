import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/log.dart';

class WindowWidget extends StatefulWidget {
  final Widget child;

  const WindowWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<WindowWidget> createState() => _WindowWidgetState();
}

class _WindowWidgetState extends State<WindowWidget> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _isMaximized = Get.find<StorageService>().read('windowMaximize') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!GetPlatform.isDesktop) {
      return widget.child;
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
              onPanStart: (_) => appWindow.startDragging(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MinimizeWindowButton(colors: buttonColors),
                  MaximizeWindowButton(colors: buttonColors, onPressed: _handleMaximize),
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

  void _handleMaximize() {
    appWindow.maximizeOrRestore();

    _isMaximized = !_isMaximized;

    Log.info(_isMaximized ? 'Maximized window' : 'Restored window');
    Get.find<StorageService>().write('windowMaximize', _isMaximized);
  }
}
