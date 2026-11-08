import 'package:flutter/material.dart';

enum AdaptivePane { left, right }

/// The same two route stacks survive both compact and expanded layouts.
final adaptivePaneNavigation = AdaptivePaneNavigation();

class AdaptivePaneNavigation extends ChangeNotifier {
  bool mounted = false;
  bool compact = false;
  bool _notificationPending = false;
  int _sequence = 0;
  PageRoute<dynamic>? _rightBoundaryRoute;

  /// The current compact cross-pane transition, or the first right content
  /// route. Retain popped transitions until their reverse animation finishes.
  PageRoute<dynamic>? get rightBoundaryRoute => _rightBoundaryRoute;

  void _watchRightBoundary(PageRoute<dynamic>? route) {
    _rightBoundaryRoute?.animation?.removeStatusListener(_boundaryStatusChanged);
    _rightBoundaryRoute = route;
    route?.animation?.addStatusListener(_boundaryStatusChanged);
  }

  final _leftSources = <PageRoute<dynamic>, PageRoute<dynamic>>{};
  final _rightPredecessors = <PageRoute<dynamic>, Route<dynamic>?>{};

  PageRoute<dynamic>? leftSourceFor(Route<dynamic>? route) {
    final source = _leftSources[route];
    if (source == null) {
      return null;
    }
    return _routes[AdaptivePane.left]!.contains(source) ? source : topPageRoute(AdaptivePane.left);
  }

  bool crossesFrom(Route<dynamic>? route, Route<dynamic>? previous) =>
      _leftSources.containsKey(route) && identical(_rightPredecessors[route], previous);

  /// Keep older right-stack pages alive, but do not paint them behind an
  /// incoming/outgoing page whose actual source is the left search pane.
  bool hidesRightRoute(Route<dynamic>? route) {
    final boundary = _rightBoundaryRoute;
    if (route == null || !mounted || !compact || boundary == null || !_leftSources.containsKey(boundary)) {
      return false;
    }
    final routes = _routes[AdaptivePane.right]!;
    final index = routes.indexOf(route);
    final boundaryIndex = routes.indexOf(boundary);
    return index >= 0 && (boundaryIndex < 0 || index < boundaryIndex);
  }

  void _restoreBoundary() {
    final routes = _routes[AdaptivePane.right]!;
    final cross = routes.whereType<PageRoute<dynamic>>().where(_leftSources.containsKey).lastOrNull;
    final first = routes.length > 1 && routes[1] is PageRoute<dynamic> ? routes[1] as PageRoute<dynamic> : null;
    _watchRightBoundary(cross ?? first);
  }

  void _boundaryStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !_routes[AdaptivePane.right]!.contains(_rightBoundaryRoute)) {
      _leftSources.remove(_rightBoundaryRoute);
      _rightPredecessors.remove(_rightBoundaryRoute);
      _restoreBoundary();
    }
    _changed();
  }

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
    _watchRightBoundary(null);
    for (final routes in _routes.values) {
      routes.clear();
    }
    _activity.clear();
    _leftSources.clear();
    _rightPredecessors.clear();
  }

  void focus(AdaptivePane pane) {
    final routes = _routes[pane]!;
    if (routes.isEmpty || (pane == AdaptivePane.right && routes.length == 1)) {
      return;
    }
    _activity[routes.last] = ++_sequence;
    _changed();
  }

  Route<dynamic>? baseRoute(AdaptivePane pane) => _routes[pane]!.firstOrNull;

  PageRoute<dynamic>? topPageRoute(AdaptivePane pane) {
    final route = _routes[pane]!.lastOrNull;
    return route is PageRoute<dynamic> ? route : null;
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
    final fromLeft = pane == AdaptivePane.right && owner.compact && owner.activePane == AdaptivePane.left;
    final source = owner.topPageRoute(AdaptivePane.left);
    owner._routes[pane]!.add(route);
    if (fromLeft && previousRoute != null && source != null && route is PageRoute<dynamic>) {
      owner._leftSources[route] = source;
      owner._rightPredecessors[route] = previousRoute;
      owner._watchRightBoundary(route);
    } else if (pane == AdaptivePane.right && owner._routes[pane]!.length == 2 && route is PageRoute<dynamic>) {
      owner._watchRightBoundary(route);
    }
    owner.focus(pane);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route, retainTransition: true);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  void _remove(Route<dynamic> route, {bool retainTransition = false}) {
    final routes = owner._routes[pane]!;
    final index = routes.indexOf(route);
    final previous = index > 0 ? routes[index - 1] : null;
    routes.remove(route);
    owner._activity.remove(route);
    // The visible return target can be the left pane even when another old
    // right route remains below this one. Interactive cancellation does not pop.
    final source = owner.topPageRoute(AdaptivePane.left);
    final returnsLeft = pane == AdaptivePane.right && owner.compact && owner.activePane == AdaptivePane.left;
    if (retainTransition && returnsLeft && source != null && route is PageRoute<dynamic> && route.animation?.status != AnimationStatus.dismissed) {
      owner._leftSources[route] = source;
      owner._rightPredecessors[route] = previous;
      owner._watchRightBoundary(route);
    } else if (identical(route, owner._rightBoundaryRoute) &&
        (!retainTransition || owner._rightBoundaryRoute?.animation?.status == AnimationStatus.dismissed)) {
      owner._leftSources.remove(route);
      owner._rightPredecessors.remove(route);
      owner._restoreBoundary();
    } else if (!identical(route, owner._rightBoundaryRoute)) {
      owner._leftSources.remove(route);
      owner._rightPredecessors.remove(route);
    }
    if (!retainTransition) {
      for (final key in owner._rightPredecessors.keys.toList()) {
        if (identical(owner._rightPredecessors[key], route)) {
          owner._rightPredecessors[key] = previous;
        }
      }
    }
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
    final source = owner._leftSources.remove(oldRoute);
    final previous = owner._rightPredecessors.remove(oldRoute);
    if (source != null && newRoute is PageRoute<dynamic>) {
      owner._leftSources[newRoute] = source;
      owner._rightPredecessors[newRoute] = previous;
    }
    for (final key in owner._rightPredecessors.keys.toList()) {
      if (identical(owner._rightPredecessors[key], oldRoute)) {
        owner._rightPredecessors[key] = newRoute;
      }
    }
    if (pane == AdaptivePane.left && newRoute is PageRoute<dynamic>) {
      for (final key in owner._leftSources.keys.toList()) {
        if (identical(owner._leftSources[key], oldRoute)) {
          owner._leftSources[key] = newRoute;
        }
      }
    }
    if (identical(oldRoute, owner._rightBoundaryRoute)) {
      owner._watchRightBoundary(newRoute is PageRoute<dynamic> ? newRoute : null);
    }
    owner._activity.remove(oldRoute);
    owner.focus(pane);
  }
}
