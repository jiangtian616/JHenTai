import 'package:flutter/widgets.dart';

enum SwipeDirection { left, right }

/// Resolve a finished swipe gesture to a direction.
///
/// [dx] and [dy] are the movement from pointer down to pointer up.
/// A swipe is only recognized when it is long enough ([thresholdRatio] * [width]) and mostly horizontal.
SwipeDirection? resolveHorizontalSwipe({
  required double dx,
  required double dy,
  required double width,
  required double thresholdRatio,
}) {
  if (width <= 0) {
    return null;
  }

  if (dx.abs() < width * thresholdRatio) {
    return null;
  }

  if (dx.abs() < dy.abs() * 2) {
    return null;
  }

  return dx < 0 ? SwipeDirection.left : SwipeDirection.right;
}

/// Turns a horizontal swipe into a single page turn instead of dragging the page with the finger.
///
/// Used when "enable turn page animation" is off, so that swiping switches pages immediately
/// instead of dragging the page and playing a snap animation.
///
/// It uses a raw [Listener] so it does not take part in the gesture arena and never conflicts with pinch zoom.
class EHSwipePageTurner extends StatefulWidget {
  final Widget child;

  /// When false, this widget does nothing and the child keeps its own drag behaviour.
  final bool enabled;

  /// Return false to ignore the swipe, e.g. the image is zoomed in and the user is just panning.
  final bool Function()? canSwipe;

  /// Finger moved to the left.
  final VoidCallback onSwipeLeft;

  /// Finger moved to the right.
  final VoidCallback onSwipeRight;

  /// Minimum swipe distance relative to the width of this widget.
  final double thresholdRatio;

  const EHSwipePageTurner({
    Key? key,
    required this.child,
    required this.enabled,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.canSwipe,
    this.thresholdRatio = 0.12,
  }) : super(key: key);

  @override
  State<EHSwipePageTurner> createState() => _EHSwipePageTurnerState();
}

class _EHSwipePageTurnerState extends State<EHSwipePageTurner> {
  final Map<int, Offset> _downPositions = {};

  /// pinch / multi finger gestures are never a swipe
  bool _multiTouch = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    /// more than one finger means a pinch, never a swipe
    _multiTouch = _downPositions.isNotEmpty;
    _downPositions[event.pointer] = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    Offset? down = _downPositions.remove(event.pointer);

    /// only the last finger leaving decides
    if (down == null || _downPositions.isNotEmpty || _multiTouch) {
      return;
    }

    /// ignore while the image is zoomed in, the user is panning it
    if (!(widget.canSwipe?.call() ?? true)) {
      return;
    }

    double width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    Offset delta = event.position - down;

    SwipeDirection? direction = resolveHorizontalSwipe(dx: delta.dx, dy: delta.dy, width: width, thresholdRatio: widget.thresholdRatio);
    switch (direction) {
      case SwipeDirection.left:
        widget.onSwipeLeft();
      case SwipeDirection.right:
        widget.onSwipeRight();
      case null:
        break;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _downPositions.remove(event.pointer);
    if (_downPositions.isEmpty) {
      _multiTouch = false;
    }
  }
}
