import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/native_window_geometry.dart';

final _rootRouteChanges = ValueNotifier<int>(0);

/// Root routes can cover a nested navigator without changing its current route.
class NativeWindowRouteObserver extends NavigatorObserver {
  void _changed() => _rootRouteChanges.value++;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _changed();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _changed();
}

class _ScrollTarget {
  final State state;
  bool visible;
  VoidCallback onPressed;
  _ScrollTarget(this.state, this.visible, this.onPressed);

  bool get available {
    if (!state.mounted || !visible) {
      return false;
    }
    var hidden = false;
    state.context.visitAncestorElements((element) {
      final widget = element.widget;
      if ((widget is Offstage && widget.offstage) || (widget is Visibility && !widget.visible)) {
        hidden = true;
      }
      return !hidden;
    });
    if (hidden) {
      return false;
    }
    // A nested route can be current while a reader or dialog covers the root.
    BuildContext context = state.context;
    NavigatorState? previous;
    while (true) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        return false;
      }
      final navigator = Navigator.maybeOf(context);
      if (navigator == null || navigator == previous) {
        break;
      }
      previous = navigator;
      context = navigator.context;
    }
    return true;
  }
}

class _ScrollTargets extends ChangeNotifier {
  final entries = <State, _ScrollTarget>{};
  _ScrollTarget? active;
  bool pending = false;
  bool alive = true;
  void schedule() {
    if (pending || !alive) {
      return;
    }
    pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pending = false;
      if (!alive) {
        return;
      }
      final available = entries.values.where((entry) => entry.available);
      final next = available.isEmpty ? null : available.last;
      if (next != active) {
        active = next;
        notifyListeners();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    alive = false;
    super.dispose();
  }
}

class _ScrollTargetScope extends InheritedWidget {
  final _ScrollTargets targets;
  const _ScrollTargetScope({required this.targets, required super.child});
  @override
  bool updateShouldNotify(_ScrollTargetScope oldWidget) => oldWidget.targets != targets;
}

/// Placed at the app builder, outside nested navigators and their safe areas.
class NativeWindowChrome extends StatefulWidget {
  final Widget child;
  final NativeWindowGeometryController? controller;
  final ValueChanged<Map<dynamic, dynamic>>? onDiagnostic;
  const NativeWindowChrome({super.key, required this.child, this.controller, this.onDiagnostic});
  @override
  State<NativeWindowChrome> createState() => _NativeWindowChromeState();
}

class _NativeWindowChromeState extends State<NativeWindowChrome> with WidgetsBindingObserver {
  late final controller = widget.controller ?? NativeWindowGeometryController(onDiagnostic: widget.onDiagnostic);
  final targets = _ScrollTargets();
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rootRouteChanges.addListener(targets.schedule);
    controller.start();
  }

  @override
  void didChangeMetrics() {
    controller.refresh();
    targets.schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => foreground = state == AppLifecycleState.resumed);
    if (foreground) {
      controller.refresh();
      targets.schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rootRouteChanges.removeListener(targets.schedule);
    targets.dispose();
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => NativeWindowGeometryScope(
            viewport: constraints.biggest,
            controller: controller,
            child: _ScrollTargetScope(
                targets: targets,
                child: Listener(
                  onPointerUp: (_) => targets.schedule(),
                  child: Stack(fit: StackFit.expand, children: [
                    widget.child,
                    AnimatedBuilder(
                        animation: Listenable.merge([controller, targets]),
                        builder: (context, _) {
                          final geometry = NativeWindowGeometryScope.geometryOf(context);
                          final rail = geometry?.rightRail;
                          final target = targets.active;
                          if (!foreground || rail == null || target == null || !target.available) {
                            return const SizedBox.shrink();
                          }
                          final side = math.min(56.0, rail.width - 8).clamp(44.0, 56.0);
                          final media = MediaQuery.of(context);
                          final bottom = math.max(geometry!.safeArea.bottom, media.viewInsets.bottom) + 16;
                          final top = geometry.size.height - bottom - side;
                          // Never move a button over the system status group in a short window.
                          if (top < geometry.statusBar.bottom + 12) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            left: rail.center.dx - side / 2,
                            top: top,
                            width: side,
                            height: side,
                            child: FloatingActionButton(
                                key: const ValueKey('native-rail-scroll-to-top'),
                                heroTag: null,
                                onPressed: () {
                                  if (target.available) {
                                    target.onPressed();
                                  }
                                  targets.schedule();
                                },
                                child: const Icon(Icons.arrow_upward)),
                          );
                        }),
                  ]),
                )),
          ));
}

/// The page keeps its normal FAB when no native rail is present. For a rail it
/// publishes the same action to the window layer instead of offsetting a FAB
/// inside a possibly narrower Scaffold.
class NativeWindowScrollToTop extends StatefulWidget {
  final bool visible;
  final VoidCallback onPressed;
  final Widget child;
  const NativeWindowScrollToTop({super.key, required this.visible, required this.onPressed, required this.child});
  @override
  State<NativeWindowScrollToTop> createState() => _NativeWindowScrollToTopState();
}

class _NativeWindowScrollToTopState extends State<NativeWindowScrollToTop> {
  _ScrollTargets? targets;
  @override
  Widget build(BuildContext context) {
    ModalRoute.of(context); // Re-evaluate when this route is covered or restored.
    final next = context.dependOnInheritedWidgetOfExactType<_ScrollTargetScope>()?.targets;
    if (targets != next) {
      targets?.entries.remove(this);
      targets?.schedule();
      targets = next;
    }
    if (next != null) {
      final entry = next.entries.putIfAbsent(this, () => _ScrollTarget(this, widget.visible, widget.onPressed));
      entry.visible = widget.visible;
      entry.onPressed = widget.onPressed;
      next.schedule();
    }
    final rail = NativeWindowGeometryScope.geometryOf(context)?.rightRail;
    return next != null && rail != null ? const SizedBox.shrink() : widget.child;
  }

  @override
  void dispose() {
    targets?.entries.remove(this);
    targets?.schedule();
    super.dispose();
  }
}
