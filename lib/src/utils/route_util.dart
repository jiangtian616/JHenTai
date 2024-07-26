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
