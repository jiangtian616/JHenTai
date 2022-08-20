import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/read/widget/eh_scrollable_positioned_list.dart';

import '../setting/mouse_setting.dart';

class EHWheelSpeedControllerForReadPage extends StatelessWidget {
  final Widget child;
  final EHItemScrollController scrollController;

  const EHWheelSpeedControllerForReadPage({
    Key? key,
    required this.child,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!GetPlatform.isDesktop) {
      return child;
    }

    return Listener(
      /// For some reason (probably because of the high resolution monitor), scroll by mouse wheel is very slow,
      /// so i call [animateTo] to simulate a faster scroll speed.
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          final double delta = event.scrollDelta.dy * MouseSetting.wheelScrollSpeed.value;

          if (delta != 0.0) {
            GestureBinding.instance.pointerSignalResolver.resolve(event);

            GestureBinding.instance.pointerSignalResolver.register(
              event,
              (_) {
                scrollController.scrollOffset(
                  offset: delta,
                  duration: const Duration(milliseconds: 200),
                );
              },
            );
          }
        }
      },
      child: child,
    );
  }
}
