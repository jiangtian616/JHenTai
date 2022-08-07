import 'package:flutter/widgets.dart';

class TabBarIcon {
  final String name;
  final String routeName;
  final Icon selectedIcon;
  final Icon unselectedIcon;
  final ValueGetter<Widget> page;
  bool shouldRender;
  bool enterNewRoute;

  TabBarIcon({
    required this.name,
    required this.routeName,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.page,
    required this.shouldRender,
    this.enterNewRoute = false,
  });
}
