import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/routes/eh_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../model/jh_layout.dart';
import '../pages/layout/desktop/desktop_layout_page_logic.dart';

/// adaptive to different layout
Future<T?>? toRoute<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  bool? offAllBefore,
  Map<String, String>? parameters,
  int? id,
}) {
  EHPage page = Routes.pages.firstWhere((page) => page.name == routeName);

  /// only one [Route]
  if (styleSetting.isInMobileLayout || page.side == Side.fullScreen || id == fullScreen) {
    return Get.toNamed(
      routeName,
      arguments: arguments,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  if (page.side == Side.left) {
    if (styleSetting.layout.value == LayoutMode.desktop) {
      DesktopLayoutPageLogic logic = Get.find<DesktopLayoutPageLogic>();

      int? tabIndex = logic.state.icons.firstIndexWhereOrNull((icon) => icon.routeName == routeName);
      if (tabIndex != null) {
        logic.handleTapTabBarButton(tabIndex);
        return Future.value(null);
      } else {
        return Get.toNamed(
          routeName,
          arguments: arguments,
          id: left,
          parameters: parameters,
          preventDuplicates: preventDuplicates,
        );
      }
    }

    /// left [Route]
    return Get.toNamed(
      routeName,
      arguments: arguments,
      id: styleSetting.isInV2Layout ? leftV2 : left,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  if (offAllBefore ?? page.offAllBefore) {
    Get.until(
      (route) => route.settings.name == Routes.blank,
      id: styleSetting.isInV2Layout ? rightV2 : right,
    );

    Get.engine.addPostFrameCallback((_) {
      Get.toNamed(
        routeName,
        arguments: arguments,
        id: styleSetting.isInV2Layout ? rightV2 : right,
        parameters: parameters,
        preventDuplicates: preventDuplicates,
      );
    });

    return null;
  }

  /// right [Route]
  if (preventDuplicates && isRouteAtTop(routeName)) {
    return null;
  }

  return Get.toNamed(
    routeName,
    arguments: arguments,
    id: styleSetting.isInV2Layout ? rightV2 : right,
    parameters: parameters,
    preventDuplicates: preventDuplicates,
  );
}

/// pop current route
void backRoute<T>({
  String? currentRoute,
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == currentRoute)?.side ?? Side.fullScreen;

  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
    id: styleSetting.isInMobileLayout
        ? null
        : side == Side.left
            ? styleSetting.isInV2Layout
                ? leftV2
                : left
            : side == Side.right
                ? styleSetting.isInV2Layout
                    ? rightV2
                    : right
                : null,
  );
}

/// pop current active route triggered by esc or fifth button or system back button
void popLeftRoute<T>({
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
    id: styleSetting.isInMobileLayout
        ? null
        : styleSetting.isInV2Layout
            ? leftV2
            : left,
  );
}

/// pop current active right route triggered by esc or fifth button or system back button

void popRightRoute<T>({
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
    id: styleSetting.isInMobileLayout
        ? null
        : styleSetting.isInV2Layout
            ? rightV2
            : right,
  );
}

/// pop current route and push a new route
Future<T?>? offRoute<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  Map<String, String>? parameters,
}) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == routeName)?.side ?? Side.fullScreen;

  return Get.offNamed(
    routeName,
    arguments: arguments,
    id: styleSetting.isInMobileLayout
        ? null
        : side == Side.left
            ? styleSetting.isInV2Layout
                ? leftV2
                : left
            : side == Side.right
                ? styleSetting.isInV2Layout
                    ? rightV2
                    : right
                : null,
    preventDuplicates: preventDuplicates,
    parameters: parameters,
  );
}

/// pop routes until [predicate] match
void untilRoute({String? currentRoute, required RoutePredicate predicate}) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == currentRoute)?.side ?? Side.fullScreen;

  return Get.until(
    predicate,
    id: styleSetting.isInMobileLayout
        ? null
        : side == Side.left
            ? styleSetting.isInV2Layout
                ? leftV2
                : left
            : side == Side.right
                ? styleSetting.isInV2Layout
                    ? rightV2
                    : right
                : null,
  );
}

/// pop all pages in right screen if exists
void untilRoute2BlankPage() {
  if (Get.keys.containsKey(right) && Get.keys[right]?.currentContext != null) {
    Get.until((route) => route.settings.name == Routes.blank, id: right);
  }

  if (Get.keys.containsKey(rightV2) && Get.keys[rightV2]?.currentContext != null) {
    Get.until((route) => route.settings.name == Routes.blank, id: rightV2);
  }
}

/// pop all pages in right screen if exists
void untilRoute2DesktopHomePage() {
  Get.until((route) => route.settings.name == Routes.desktopHome, id: left);
}

/// check if route with [routeName] is at top
bool isRouteAtTop(String routeName) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == routeName)?.side ?? Side.fullScreen;

  if (styleSetting.isInMobileLayout || side == Side.fullScreen) {
    return Get.currentRoute == routeName;
  }

  if (side == Side.left) {
    if (styleSetting.actualLayout == LayoutMode.desktop) {
      DesktopLayoutPageLogic logic = Get.find<DesktopLayoutPageLogic>();
      return logic.state.icons[logic.state.selectedTabIndex].routeName == routeName || leftRouting.current == routeName;
    }
    return leftRouting.current == routeName;
  }

  return rightRouting.current == routeName;
}

/// Switch layout mode, and move the pages opened in the old layout into the navigators of the new layout.
///
/// Pages live in different navigators in different layouts: the root navigator in mobile layout, [leftV2] & [rightV2] in tablet
/// layout, [left] & [right] in desktop layout. Switching layout only replaces the layout widget in [HomePage], so pages opened
/// before would stay where they are, e.g. setting pages opened in mobile layout would keep covering the new tablet layout in full
/// screen until they are popped. So pop them from the old navigators and push them again into the new ones, they will be rebuilt.
Future<void> switchLayoutMode(LayoutMode layoutMode) async {
  LayoutMode oldLayout = styleSetting.actualLayout;
  LayoutMode newLayout = styleSetting.resolveActualLayout(layoutMode);

  /// pop before saving, because nested navigators of the old layout are disposed once [HomePage] rebuilds
  List<RouteSettings> openedRoutes = oldLayout == newLayout ? [] : _popOpenedRoutes(oldLayout);

  Future<void> saveFuture = styleSetting.saveLayoutMode(layoutMode);
  if (openedRoutes.isNotEmpty) {
    _pushOpenedRoutesAfterLayoutBuilt(openedRoutes, newLayout);
  }
  await saveFuture;
}

/// Pop pages opened in [layout], return their settings in the order they were pushed, left side pages first.
List<RouteSettings> _popOpenedRoutes(LayoutMode layout) {
  if (layout == LayoutMode.mobileV2 || layout == LayoutMode.mobile) {
    return _popRoutesAbove(Routes.home);
  }
  if (layout == LayoutMode.tabletV2 || layout == LayoutMode.tablet) {
    return [..._popRoutesAbove(Routes.mobileLayoutV2, id: leftV2), ..._popRoutesAbove(Routes.blank, id: rightV2)];
  }
  return [..._popRoutesAbove(Routes.desktopHome, id: left), ..._popRoutesAbove(Routes.blank, id: right)];
}

/// Pop pages above [baseRouteName] in navigator [id], return their settings in the order they were pushed.
List<RouteSettings> _popRoutesAbove(String baseRouteName, {int? id}) {
  if (id != null && Get.keys[id]?.currentState == null) {
    return [];
  }

  List<RouteSettings> routes = [];
  bool reachedBase = false;
  Get.until(
    (route) {
      if (route.isFirst || route.settings.name == baseRouteName) {
        reachedBase = true;
        return true;
      }

      Side? side = _sideOfRoute(route.settings.name);

      /// full screen pages like read page stay in the root navigator in every layout
      if (side == Side.fullScreen) {
        return true;
      }

      /// routes that are not pages, e.g. dialogs, are just popped
      if (side != null) {
        routes.insert(0, route.settings);
      }
      return false;
    },
    id: id,
  );

  /// they were opened above a full screen page which can't be moved, so put them back
  if (!reachedBase) {
    _pushRoutesOneByOne(routes, (route) => Get.toNamed(route.name!, arguments: route.arguments, id: id, preventDuplicates: false));
    return [];
  }

  return routes;
}

/// Push [routes] into the navigators of [layout] after [HomePage] has built it.
void _pushOpenedRoutesAfterLayoutBuilt(List<RouteSettings> routes, LayoutMode layout, {int retry = 0}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_isLayoutBuilt(layout)) {
      _pushOpenedRoutes(routes, layout);
    } else if (retry < 10) {
      _pushOpenedRoutesAfterLayoutBuilt(routes, layout, retry: retry + 1);
    } else if (_isLayoutBuilt(styleSetting.actualLayout)) {
      /// layout changed again in the meantime, e.g. window resized
      _pushOpenedRoutes(routes, styleSetting.actualLayout);
    }
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

bool _isLayoutBuilt(LayoutMode layout) {
  if (styleSetting.actualLayout != layout) {
    return false;
  }
  if (layout == LayoutMode.mobileV2 || layout == LayoutMode.mobile) {
    return true;
  }
  if (layout == LayoutMode.tabletV2 || layout == LayoutMode.tablet) {
    return Get.keys[leftV2]?.currentState != null && Get.keys[rightV2]?.currentState != null;
  }
  return Get.keys[left]?.currentState != null && Get.keys[right]?.currentState != null;
}

void _pushOpenedRoutes(List<RouteSettings> routes, LayoutMode layout) {
  bool inMobileLayout = layout == LayoutMode.mobileV2 || layout == LayoutMode.mobile;
  bool inTabletLayout = layout == LayoutMode.tabletV2 || layout == LayoutMode.tablet;

  /// setting list is a tab rather than a page in desktop layout, select it to show it beside setting pages
  if (layout == LayoutMode.desktop && routes.first.name!.startsWith(Routes.settingPrefix)) {
    toRoute(Routes.setting);
  }

  _pushRoutesOneByOne(routes, (route) {
    if (inMobileLayout) {
      Get.toNamed(route.name!, arguments: route.arguments, preventDuplicates: false);
    } else if (_sideOfRoute(route.name) == Side.left) {
      /// left pages may be tabs in desktop layout, which [toRoute] handles
      toRoute(route.name!, arguments: route.arguments, preventDuplicates: false);
    } else {
      /// not [toRoute], which pushes pages with [EHPage.offAllBefore] in the next frame and would break the order
      Get.toNamed(route.name!, arguments: route.arguments, id: inTabletLayout ? rightV2 : right, preventDuplicates: false);
    }
  });
}

/// Pages read global [Get.arguments] when they are built in the next frame, so push them one frame after another.
void _pushRoutesOneByOne(List<RouteSettings> routes, void Function(RouteSettings route) push) {
  if (routes.isEmpty) {
    return;
  }

  push(routes.first);

  if (routes.length > 1) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushRoutesOneByOne(routes.sublist(1), push));
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

Side? _sideOfRoute(String? routeName) {
  return Routes.pages.firstWhereOrNull((page) => page.name == routeName?.split('?')[0])?.side;
}
