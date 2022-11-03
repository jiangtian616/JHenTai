import 'package:flutter/widgets.dart';

class TabBarIcon {
  final String name;
  final String routeName;
  final Icon selectedIcon;
  final Icon unselectedIcon;
  final ValueGetter<Widget> page;
  final ValueGetter<ScrollController>? scrollController;
  bool shouldRender;
  bool enterNewRoute;

  TabBarIcon({
    required this.name,
    required this.routeName,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.page,
    this.scrollController,
    required this.shouldRender,
    this.enterNewRoute = false,
  });
}
