import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/router_report.dart';

/// make sure GetXController will be recycled when using native Navigator api by letting
/// GetX be aware of native Navigator api operation
class GetXRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouterReportManager.reportCurrentRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    RouterReportManager.reportRouteWillDispose(route);
  }
}
