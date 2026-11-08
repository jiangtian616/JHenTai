import 'package:flutter/material.dart';

import 'adaptive_pane_navigation.dart';

/// Use Flutter's normal Hero flight between the retained list and the first
/// compact detail route. The right Navigator owns the flight overlay; in the
/// compact layout both stacks occupy the same viewport coordinate space.
class AdaptivePaneHeroController extends HeroController {
  final AdaptivePaneNavigation navigation;

  AdaptivePaneHeroController(this.navigation) : super(createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end));

  Route<dynamic>? _visiblePrevious(Route<dynamic>? route) {
    if (route != null && navigation.compact && identical(route, navigation.baseRoute(AdaptivePane.right))) {
      return navigation.topPageRoute(AdaptivePane.left) ?? route;
    }
    return route;
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (navigation.compact && navigation.crossesFrom(topRoute, previousTopRoute)) {
      super.didChangeTop(topRoute, navigation.leftSourceFor(topRoute));
    } else if (navigation.compact && navigation.crossesFrom(previousTopRoute, topRoute)) {
      super.didChangeTop(navigation.leftSourceFor(previousTopRoute) ?? topRoute, previousTopRoute);
    } else {
      super.didChangeTop(_visiblePrevious(topRoute)!, _visiblePrevious(previousTopRoute));
    }
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route,
        navigation.compact && navigation.crossesFrom(route, previousRoute) ? navigation.leftSourceFor(route) : _visiblePrevious(previousRoute));
  }
}
