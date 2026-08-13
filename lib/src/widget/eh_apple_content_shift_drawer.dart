import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Apple-style drawer that shifts the current content to reveal a side panel.
///
/// The current content is pulled right, revealing the navigation panel below.
class EHAppleContentShiftDrawer extends StatefulWidget {
  const EHAppleContentShiftDrawer({
    super.key,
    required this.panel,
    required this.content,
    this.width = 278,
  });

  final Widget panel;
  final Widget content;
  final double width;

  @override
  State<EHAppleContentShiftDrawer> createState() =>
      EHAppleContentShiftDrawerState();
}

class EHAppleContentShiftDrawerState
    extends State<EHAppleContentShiftDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 0,
  );

  bool get _isOpen => _controller.value > 0.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() => _isOpen ? close() : open();

  void open() => _animateTo(1);

  void close() => _animateTo(0);

  void _animateTo(double target) {
    if (target > _controller.value && target == 1) {
      HapticFeedback.mediumImpact();
    }
    _controller.animateTo(target, curve: Curves.easeOutCubic);
  }

  void _onDragStart(DragStartDetails details) => _controller.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value = (_controller.value +
            (details.primaryDelta ?? 0) / widget.width)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity > 300) {
      open();
    } else if (velocity < -300) {
      close();
    } else if (_controller.value < 0.08) {
      close();
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double shift = _controller.value * widget.width;
        final bool open = _controller.value > 0.01;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: open ? close : null,
              child: RawGestureDetector(
                gestures: {
                  _DirectionalHorizontalDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _DirectionalHorizontalDragGestureRecognizer
                      >(
                        () => _DirectionalHorizontalDragGestureRecognizer(
                          openingDirection: 1,
                          isOpen: () => _controller.value > 0.01,
                        ),
                        (recognizer) {
                          recognizer
                            ..onStart = _onDragStart
                            ..onUpdate = _onDragUpdate
                            ..onEnd = _onDragEnd;
                        },
                      ),
                },
                child: Transform.translate(
                  offset: Offset(shift, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: open
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 3,
                                offset: const Offset(6, 0),
                              ),
                            ]
                          : null,
                    ),
                    child: widget.content,
                  ),
                ),
              ),
            ),
            // The panel is clipped to the part revealed by the shifted page.
            // Keeping this layer above the page makes the exposed menu area
            // receive ListTile taps reliably, while the closed state clips it
            // to zero pixels so it cannot cover the page.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.width,
              child: ClipRect(
                clipper: _EHAppleDrawerRevealClipper(shift),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: 0.92,
                  ),
                  child: widget.panel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EHAppleDrawerRevealClipper extends CustomClipper<Rect> {
  const _EHAppleDrawerRevealClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
        0,
        0,
        width.clamp(0.0, size.width),
        size.height,
      );

  @override
  bool shouldReclip(_EHAppleDrawerRevealClipper oldClipper) =>
      oldClipper.width != width;
}

/// A horizontal recognizer that only accepts the left-to-right opening swipe
/// while the navigation drawer is closed.
class _DirectionalHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _DirectionalHorizontalDragGestureRecognizer({
    required this.openingDirection,
    required this.isOpen,
  });

  final double openingDirection;
  final bool Function() isOpen;
  bool _checkedDirection = false;

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _checkedDirection = false;
    }
    if (event is PointerMoveEvent &&
        !_checkedDirection &&
        !isOpen() &&
        event.delta.dx.abs() > 0.5) {
      _checkedDirection = true;
      if (event.delta.dx * openingDirection <= 0) {
        rejectGesture(event.pointer);
        return;
      }
    }
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _checkedDirection = false;
    }
  }
}
