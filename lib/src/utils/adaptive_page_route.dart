import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/eh_page.dart';

/// Compact routes use the same page configuration and GetX defaults as the
/// fixed phone root Navigator. Wide panes keep their existing transition.
GetPageRoute<T> adaptivePageRoute<T>({
  required EHPage page,
  required RouteSettings settings,
  required bool compact,
  required bool popGesture,
  required Transition wideTransition,
  required Duration wideDuration,
  bool wideParallax = false,
}) {
  if (compact) {
    // This is the generator used by GetMaterialApp for fixed phone routes.
    // Keep page settings, bindings, middleware and transitions in one place.
    return PageRedirect(settings: settings).page<T>();
  }
  return GetPageRoute<T>(
    settings: settings,
    page: page.page,
    popGesture: popGesture,
    transition: wideTransition,
    transitionDuration: wideDuration,
    showCupertinoParallax: wideParallax,
  );
}

/// Match the outgoing phone route as well: the home route does not slide,
/// while a Cupertino search route supplies the usual back-page parallax.
bool usesPhoneParallax(Route<dynamic>? source, Route<dynamic>? destination) =>
    source is GetPageRoute && source.transition == Transition.cupertino && destination is GetPageRoute && destination.showCupertinoParallax;
