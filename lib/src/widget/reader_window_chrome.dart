import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/native_window_geometry.dart';

/// Reader layout stays active independently of the immersive visibility setting.
class ReaderWindowSession extends StatefulWidget {
  final Widget child;
  final bool immersiveMode;
  const ReaderWindowSession(
      {super.key, required this.immersiveMode, required this.child});
  @override
  State<ReaderWindowSession> createState() => _ReaderWindowSessionState();
}

class _ReaderWindowSessionState extends State<ReaderWindowSession> {
  NativeWindowGeometryController? _controller;
  bool _retained = false;
  bool _supportsEdgeChrome = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = NativeWindowGeometryScope.controllerOf(context);
    if (controller != _controller) {
      _controller?.releaseReader(this);
      _controller = controller;
      _retained = false;
    }
    final geometry = NativeWindowGeometryScope.geometryOf(context);
    if (geometry != null) {
      // Capture the side rail before hiding status content. Retain this
      // ability across a fold during reading; ordinary compact iPhones keep
      // their physical top safe area.
      _supportsEdgeChrome = _supportsEdgeChrome ||
          controller?.supportsReaderEdgeChrome == true ||
          geometry.rightRail != null ||
          geometry.size.shortestSide >= 600;
      if (!_retained) {
        _retained = true;
        controller?.retainReader(this, immersive: widget.immersiveMode);
      }
    }
  }

  @override
  void didUpdateWidget(ReaderWindowSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_retained && oldWidget.immersiveMode != widget.immersiveMode) {
      _controller?.retainReader(this, immersive: widget.immersiveMode);
    }
  }

  @override
  void dispose() {
    _controller?.releaseReader(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = NativeWindowGeometryScope.geometryOf(context);
    return ReaderWindowScope(
        edgeToEdge: _supportsEdgeChrome && geometry != null,
        child: widget.child);
  }
}

class ReaderWindowScope extends InheritedWidget {
  final bool edgeToEdge;
  const ReaderWindowScope(
      {super.key, required this.edgeToEdge, required super.child});
  static bool isReading(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderWindowScope>() != null;
  static bool isEdgeToEdge(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReaderWindowScope>()
          ?.edgeToEdge ??
      false;
  @override
  bool updateShouldNotify(ReaderWindowScope oldWidget) =>
      edgeToEdge != oldWidget.edgeToEdge;
}

/// A 40-point reader menu overlays the images at the top, with no extra native
/// top band on Duo. Only its controls reserve space for system status icons.
class ReaderTopMenu extends StatelessWidget {
  final bool visible;
  final double toolbarHeight;
  final AppBar appBar;
  final Color backgroundColor;
  const ReaderTopMenu(
      {super.key,
      required this.visible,
      required this.toolbarHeight,
      required this.appBar,
      this.backgroundColor = Colors.transparent});

  @override
  Widget build(BuildContext context) {
    final compact = ReaderWindowScope.isEdgeToEdge(context);
    final geometry = NativeWindowGeometryScope.geometryOf(context);
    final media = MediaQuery.of(context);
    final height = toolbarHeight + (compact ? 0 : media.padding.top);
    final rightInset = compact
        ? math.max(media.padding.right, geometry?.safeArea.right ?? 0.0)
        : media.padding.right;
    final reserve = compact && geometry?.statusBarHidden == false
        ? geometry!.horizontalBars
            ? geometry.headerTrailingWidth
            : geometry.rightRail == null
                ? 0.0
                : geometry.rightRail!.width + 12
        : 0.0;
    Widget bar = appBar;
    if (compact) {
      bar = Theme(
          data: Theme.of(context).copyWith(
              appBarTheme: Theme.of(context)
                  .appBarTheme
                  .copyWith(toolbarHeight: toolbarHeight)),
          child: bar);
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      top: visible ? 0 : -height,
      height: height,
      left: 0,
      right: 0,
      child: MediaQuery(
        data: compact
            ? media.copyWith(
                padding: media.padding.copyWith(top: 0, right: rightInset))
            : media,
        child: ColoredBox(
            color: backgroundColor,
            child: Padding(
                padding:
                    EdgeInsets.only(right: math.max(0.0, reserve - rightInset)),
                child: bar)),
      ),
    );
  }
}
