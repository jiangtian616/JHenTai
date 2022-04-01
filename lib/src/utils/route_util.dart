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
}) {
  Side side = Routes.pages.firstWhere((page) => page.name == routeName).side;

  return Get.toNamed(
    routeName,
    arguments: arguments,
    id: StyleSetting.enableTabletLayout.isFalse
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

void back<T>(
  String currentRouteName, {
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  Side side = Routes.pages.firstWhere((page) => page.name == currentRouteName).side;
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
    id: StyleSetting.enableTabletLayout.isFalse
        ? null
        : side == Side.left
            ? left
            : side == Side.right
                ? right
                : null,
  );
}

Future<T?>? offNamed<T>(
  String currentRouteName,
  String page, {
  dynamic arguments,
  bool preventDuplicates = true,
  Map<String, String>? parameters,
}) {
  Side side = Routes.pages.firstWhere((page) => page.name == currentRouteName).side;
  return Get.offNamed(
    page,
    arguments: arguments,
    id: StyleSetting.enableTabletLayout.isFalse
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

void until(String currentRouteName, RoutePredicate predicate) {
  Side side = Routes.pages.firstWhere((page) => page.name == currentRouteName).side;
  return Get.until(
    predicate,
    id: StyleSetting.enableTabletLayout.isFalse
        ? null
        : side == Side.left
            ? left
            : side == Side.right
                ? right
                : null,
  );
}
