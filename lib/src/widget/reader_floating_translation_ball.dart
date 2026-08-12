import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jhentai/src/model/reader_floating_ball_position.dart';
import 'package:jhentai/src/service/reader_action_persistence.dart';

class ReaderFloatingTranslationBall extends StatefulWidget {
  const ReaderFloatingTranslationBall({
    super.key,
    required this.isTranslating,
    required this.onTap,
    this.positionStore,
    this.icon = Icons.translate,
    this.semanticLabel = 'Reader translation',
    this.ballSize = 48,
  });

  final bool isTranslating;
  final VoidCallback onTap;
  final ReaderFloatingBallPositionStore? positionStore;
  final IconData icon;
  final String semanticLabel;
  final double ballSize;

  @override
  State<ReaderFloatingTranslationBall> createState() =>
      _ReaderFloatingTranslationBallState();
}

class _ReaderFloatingTranslationBallState
    extends State<ReaderFloatingTranslationBall> {
  static const double _edgeGap = 8;

  final ReaderFloatingBallPositionStore _defaultStore =
      ReaderFloatingBallPositionStore();
  Orientation? _orientation;
  ReaderFloatingBallPosition _position = const ReaderFloatingBallPosition(
    x: 1,
    y: 0.5,
  );
  double _opacity = 0.52;
  Timer? _idleTimer;
  bool _dragging = false;

  ReaderFloatingBallPositionStore get _store =>
      widget.positionStore ?? _defaultStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Orientation next = MediaQuery.orientationOf(context);
    if (_orientation == next) return;
    _orientation = next;
    unawaited(_restorePosition(next));
  }

  Future<void> _restorePosition(Orientation orientation) async {
    final ReaderFloatingBallPosition? restored = await _store.load(orientation);
    if (!mounted || _orientation != orientation) return;
    setState(() => _position = restored ?? _position);
  }

  void _wake() {
    _idleTimer?.cancel();
    if (_opacity != 1) setState(() => _opacity = 1);
    _idleTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_dragging) setState(() => _opacity = 0.52);
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _wake();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final Size viewport = MediaQuery.sizeOf(context);
    final double width = math.max(
      1,
      viewport.width - widget.ballSize - 2 * _edgeGap,
    );
    final MediaQueryData media = MediaQuery.of(context);
    final double height = math.max(
      1,
      viewport.height -
          widget.ballSize -
          media.padding.top -
          media.padding.bottom -
          2 * _edgeGap,
    );
    final double nextX =
        (_position.x * width + details.delta.dx).clamp(0, width) / width;
    final double nextY =
        (_position.y * height + details.delta.dy).clamp(0, height) / height;
    setState(() => _position = ReaderFloatingBallPosition(x: nextX, y: nextY));
  }

  void _onDragEnd() {
    _dragging = false;
    final ReaderFloatingBallPosition snapped =
        ReaderFloatingBallPosition(
          x: _position.x < 0.5 ? 0 : 1,
          y: _position.y,
        ).clamp();
    setState(() => _position = snapped);
    final Orientation? orientation = _orientation;
    if (orientation != null) unawaited(_store.save(orientation, snapped));
    _wake();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.shortestSide >= 600 &&
        Theme.of(context).platform == TargetPlatform.macOS) {
      // The reader already has a desktop translation menu; the ball is a
      // phone/tablet affordance and should not cover desktop controls.
      return const SizedBox.shrink();
    }
    return CustomSingleChildLayout(
      delegate: _ReaderFloatingBallLayoutDelegate(
        position: _position,
        ballSize: widget.ballSize,
        edgeGap: _edgeGap,
        padding: MediaQuery.paddingOf(context),
      ),
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _wake();
            widget.onTap();
          },
          onPanStart: _onDragStart,
          onPanUpdate: _onDragUpdate,
          onPanEnd: (_) => _onDragEnd(),
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 180),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black38, blurRadius: 8),
                ],
              ),
              child: Icon(
                widget.isTranslating ? Icons.close : widget.icon,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderFloatingBallLayoutDelegate extends SingleChildLayoutDelegate {
  _ReaderFloatingBallLayoutDelegate({
    required this.position,
    required this.ballSize,
    required this.edgeGap,
    required this.padding,
  });

  final ReaderFloatingBallPosition position;
  final double ballSize;
  final double edgeGap;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: ballSize, height: ballSize);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double availableWidth = math.max(
      1,
      size.width - padding.left - padding.right - childSize.width - 2 * edgeGap,
    );
    final double availableHeight = math.max(
      1,
      size.height -
          padding.top -
          padding.bottom -
          childSize.height -
          2 * edgeGap,
    );
    return Offset(
      padding.left + edgeGap + position.x * availableWidth,
      padding.top + edgeGap + position.y * availableHeight,
    );
  }

  @override
  bool shouldRelayout(
    covariant _ReaderFloatingBallLayoutDelegate oldDelegate,
  ) =>
      oldDelegate.position != position ||
      oldDelegate.ballSize != ballSize ||
      oldDelegate.padding != padding;
}
