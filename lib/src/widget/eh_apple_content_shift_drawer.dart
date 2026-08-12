import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum EHAppleContentShiftDrawerSide { left, right }

/// Apple-style drawer that shifts the current content to reveal a side panel.
///
/// The same interaction is used for the main navigation and the quick-search
/// panel. The panel direction changes the drag/open direction, while the
/// animation, shadow, and dismissal behavior stay identical.
class EHAppleContentShiftDrawer extends StatefulWidget {
  const EHAppleContentShiftDrawer({
    super.key,
    required this.panel,
    required this.content,
    this.width = 278,
    this.side = EHAppleContentShiftDrawerSide.left,
  });

  final Widget panel;
  final Widget content;
  final double width;
  final EHAppleContentShiftDrawerSide side;

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
  double get _direction =>
      widget.side == EHAppleContentShiftDrawerSide.left ? 1 : -1;

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
            (details.primaryDelta ?? 0) * _direction / widget.width)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = (details.primaryVelocity ?? 0) * _direction;
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
        final double shift = _controller.value * widget.width * _direction;
        final bool open = _controller.value > 0.01;
        final bool isLeft = widget.side == EHAppleContentShiftDrawerSide.left;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: isLeft ? 0 : null,
              right: isLeft ? null : 0,
              top: 0,
              bottom: 0,
              width: widget.width,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: 0.92,
                ),
                child: widget.panel,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: open ? close : null,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
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
                              offset: Offset(isLeft ? 6 : -6, 0),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.content,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
