import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class EHWheelListener extends StatelessWidget {
  final Widget child;
  final ValueChanged<PointerScrollEvent>? onPointerScroll;
  final ValueChanged<PointerPanZoomStartEvent>? onPointerPanZoomStart;
  final ValueChanged<PointerPanZoomUpdateEvent>? onPointerPanZoomUpdate;
  final ValueChanged<PointerPanZoomEndEvent>? onPointerPanZoomEnd;

  const EHWheelListener({
    Key? key,
    required this.child,
    this.onPointerScroll,
    this.onPointerPanZoomStart,
    this.onPointerPanZoomUpdate,
    this.onPointerPanZoomEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          onPointerScroll?.call(event);
        }
      },
      onPointerPanZoomStart: onPointerPanZoomStart,
      onPointerPanZoomUpdate: onPointerPanZoomUpdate,
      onPointerPanZoomEnd: onPointerPanZoomEnd,
      child: child,
    );
  }
}
