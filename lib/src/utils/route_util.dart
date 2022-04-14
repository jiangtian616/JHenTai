import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/start_page.dart';
import 'package:jhentai/src/routes/EHPage.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';

/// adaptive to tablet layout(nested navigation)

Future<T?>? toNamed<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  Map<String, String>? parameters,
  int? id,
}) {
  EHPage page = Routes.pages.firstWhere((page) => page.name == routeName);
  if (StyleSetting.currentEnableTabletLayout.isFalse || page.side == Side.fullScreen || id == fullScreen) {
    return Get.toNamed(
      routeName,
      arguments: arguments,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  if (page.side == Side.left) {
    return Get.toNamed(
      routeName,
      arguments: arguments,
      id: left,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  if (page.offAllBefore) {
    Get.until(
      (route) => route.settings.name == Routes.blank,
      id: right,
    );
  }
  return Get.toNamed(
    routeName,
    arguments: arguments,
    id: right,
    parameters: parameters,
    preventDuplicates: preventDuplicates,
  );
}

void back<T>({
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
    id: StyleSetting.currentEnableTabletLayout.isFalse
        ? null
        : side == Side.left
            ? left
            : side == Side.right
                ? right
                : null,
  );
}

Future<T?>? offNamed<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  Map<String, String>? parameters,
}) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == routeName)?.side ?? Side.fullScreen;

  return Get.offNamed(
    routeName,
    arguments: arguments,
    id: StyleSetting.currentEnableTabletLayout.isFalse
        ? null
        : side == Side.left
            ? left
            : side == Side.right
                ? right
                : null,
    preventDuplicates: preventDuplicates,
    parameters: parameters,
  );
}

void until({String? currentRoute, required RoutePredicate predicate}) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == currentRoute)?.side ?? Side.fullScreen;
  return Get.until(
    predicate,
    id: StyleSetting.currentEnableTabletLayout.isFalse
        ? null
        : side == Side.left
            ? left
            : side == Side.right
                ? right
                : null,
  );
}

/// pop all pages in right screen if exists
void untilBlankPage() {
  if (!Get.keys.containsKey(right) || Get.keys[right]?.currentContext == null) {
    return;
  }
  Get.until(
    (route) => route.settings.name == Routes.blank,
    id: right,
  );
}

bool isAtTop(String routeName) {
  Side side = Routes.pages.firstWhereOrNull((page) => page.name == routeName)?.side ?? Side.fullScreen;
  if (side == Side.fullScreen || StyleSetting.currentEnableTabletLayout.isFalse) {
    return Get.currentRoute == routeName;
  }
  if (side == Side.left) {
    return leftRouting.current == routeName;
  }
  return rightRouting.current == routeName;
}
