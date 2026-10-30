import 'package:flutter/material.dart';

enum AdaptivePane { left, right }

/// The same two route stacks survive both compact and expanded layouts.
final adaptivePaneNavigation = AdaptivePaneNavigation();

class AdaptivePaneNavigation extends ChangeNotifier {
  bool mounted = false;
  bool compact = false;
  bool _notificationPending = false;
  int _sequence = 0;
  final _routes = <AdaptivePane, List<Route<dynamic>>>{
    AdaptivePane.left: [],
    AdaptivePane.right: [],
  };
  final _activity = <Route<dynamic>, int>{};

  AdaptivePane get activePane {
    final left = _routes[AdaptivePane.left]!;
    final right = _routes[AdaptivePane.right]!;
    if (right.length <= 1) {
      return AdaptivePane.left;
    }
    if (left.isEmpty) {
      return AdaptivePane.right;
    }
    return (_activity[right.last] ?? 0) > (_activity[left.last] ?? 0) ? AdaptivePane.right : AdaptivePane.left;
  }

  void attach() => mounted = true;

  void detach() {
    mounted = false;
    compact = false;
    for (final routes in _routes.values) {
      routes.clear();
    }
    _activity.clear();
  }

  void focus(AdaptivePane pane) {
    final routes = _routes[pane]!;
    if (routes.isEmpty || (pane == AdaptivePane.right && routes.length == 1)) {
      return;
    }
    _activity[routes.last] = ++_sequence;
    _changed();
  }

  NavigatorObserver observer(AdaptivePane pane) => _PaneObserver(this, pane);

  void _changed() {
    if (_notificationPending) {
      return;
    }
    _notificationPending = true;
    // Navigator observers may run during build; update visibility next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (mounted) {
        notifyListeners();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

class _PaneObserver extends NavigatorObserver {
  final AdaptivePaneNavigation owner;
  final AdaptivePane pane;
  _PaneObserver(this.owner, this.pane);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    owner._routes[pane]!.add(route);
    owner.focus(pane);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  void _remove(Route<dynamic> route) {
    owner._routes[pane]!.remove(route);
    owner._activity.remove(route);
    owner._changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final routes = owner._routes[pane]!;
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0) {
      routes.removeAt(index);
      if (newRoute != null) {
        routes.insert(index, newRoute);
      }
    }
    owner._activity.remove(oldRoute);
    owner.focus(pane);
  }
}
