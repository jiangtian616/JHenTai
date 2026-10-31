import 'package:flutter/material.dart';
import '../utils/native_window_geometry.dart';

/// Avoid only the part of a title that actually intersects the native rail.
/// Measuring the title's full layout box accounts for its pane, cover and
/// margins, including embedded previews that do not touch the window edge.
class NativeWindowTitleInset extends StatefulWidget {
  final Widget child;
  const NativeWindowTitleInset({super.key, required this.child});
  @override
  State<NativeWindowTitleInset> createState() => _NativeWindowTitleInsetState();
}

class _NativeWindowTitleInsetState extends State<NativeWindowTitleInset> {
  double _inset = 0;
  Rect? _rail;
  bool _pending = false;
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _routeAnimation?.removeStatusListener(_routeDidSettle);
    _secondaryAnimation?.removeStatusListener(_routeDidSettle);
    _routeAnimation = route?.animation;
    _secondaryAnimation = route?.secondaryAnimation;
    _routeAnimation?.addStatusListener(_routeDidSettle);
    _secondaryAnimation?.addStatusListener(_routeDidSettle);
  }

  void _routeDidSettle(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      // Parent route transforms can change without another title layout.
      _measureAfterLayout();
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_routeDidSettle);
    _secondaryAnimation?.removeStatusListener(_routeDidSettle);
    super.dispose();
  }

  void _measureAfterLayout() {
    if (_pending) {
      return;
    }
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      final rail = _rail;
      final right = box.localToGlobal(Offset.zero).dx + box.size.width;
      final inset = rail == null ? 0.0 : (right - rail.left).clamp(0.0, box.size.width).toDouble();
      if ((inset - _inset).abs() > .1) {
        setState(() => _inset = inset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _rail = NativeWindowPane.isTrailing(context) ? NativeWindowGeometryScope.geometryOf(context)?.rightRail : null;
    return LayoutBuilder(builder: (context, constraints) {
      _measureAfterLayout();
      return SizedBox(
        width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
        child: Padding(padding: EdgeInsets.only(right: _rail == null ? 0 : _inset), child: widget.child),
      );
    });
  }
}
