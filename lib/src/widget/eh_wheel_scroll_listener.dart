import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class EHWheelListener extends StatelessWidget {
  final Widget child;
  final ValueChanged<PointerScrollEvent>? onPointerScroll;

  const EHWheelListener({Key? key, required this.child, this.onPointerScroll}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          onPointerScroll?.call(event);
        }
      },
      child: child,
    );
  }
}
