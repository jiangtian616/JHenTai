import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../config/ui_config.dart';
import '../service/windows_service.dart';

class WindowWidget extends StatefulWidget {
  final Widget child;

  const WindowWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<WindowWidget> createState() => _WindowWidgetState();
}

class _WindowWidgetState extends State<WindowWidget> with WindowListener {
  final WindowService windowService = Get.find<WindowService>();

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
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
  Widget build(BuildContext context) {
    if (!GetPlatform.isWindows) {
      return widget.child;
    }

    return Column(
      children: [
        ColoredBox(
          color: UIConfig.backGroundColor(context),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    windowManager.startDragging();
                  },
                  onDoubleTap: () async {
                    bool isMaximized = await windowManager.isMaximized();
                    if (!isMaximized) {
                      windowManager.maximize();
                    } else {
                      windowManager.unmaximize();
                    }
                  },
                  child: Container(constraints: const BoxConstraints(minHeight: 32)),
                ),
              ),
              WindowCaptionButton.minimize(
                brightness: Theme.of(context).brightness,
                onPressed: () async {
                  bool isMinimized = await windowManager.isMinimized();
                  if (isMinimized) {
                    windowManager.restore();
                  } else {
                    windowManager.minimize();
                  }
                },
              ),
              FutureBuilder<bool>(
                future: windowManager.isMaximized(),
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  if (snapshot.data == true) {
                    return WindowCaptionButton.unmaximize(
                      brightness: Theme.of(context).brightness,
                      onPressed: () {
                        windowManager.unmaximize();
                      },
                    );
                  }
                  return WindowCaptionButton.maximize(
                    brightness: Theme.of(context).brightness,
                    onPressed: () {
                      windowManager.maximize();
                    },
                  );
                },
              ),
              WindowCaptionButton.close(
                brightness: Theme.of(context).brightness,
                onPressed: () {
                  windowManager.close();
                },
              ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
