import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../setting/mouse_setting.dart';

class EHWheelSpeedController extends StatelessWidget {
  final ScrollController? controller;
  final Widget child;

  const EHWheelSpeedController({Key? key, required this.controller, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      /// For some reason (probably because of the high resolution monitor), scroll by mouse wheel is very slow,
      /// so i call [animateTo] manually to simulate a faster scroll speed.
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          if (controller == null || !controller!.hasClients) {
            return;
          }

          final double delta = event.scrollDelta.dy * MouseSetting.wheelScrollSpeed.value;
          if (delta == 0) {
            return;
          }

          GestureBinding.instance.pointerSignalResolver.resolve(event);

          ScrollPosition position = controller!.position;

          /// at edge
          if (position.pixels < position.minScrollExtent || position.pixels > position.maxScrollExtent) {
            return;
          }

          /// at edge
          if (position.pixels + delta <= 0) {
            position.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
            );
            return;
          }

          /// at edge
          if (position.pixels + delta >= position.maxScrollExtent) {
            position.animateTo(
              position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
            );
            return;
          }

          position.animateTo(
            position.pixels + delta,
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease,
          );
        }
      },
      child: child,
    );
  }
}
