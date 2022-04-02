import 'package:stack_trace/stack_trace.dart';
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
  if (StyleSetting.enableTabletLayout.isFalse) {
    return Get.toNamed(
      routeName,
      arguments: arguments,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  EHPage page = Routes.pages.firstWhere((page) => page.name == routeName);

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
  String? className,
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  if (className == null) {
    /// get caller className to decide which Navigator to pop
    List<Frame> frames = Trace.current().frames;
    String member = frames[1].member!;
    List<String> parts = member.split(".");
    className = parts[0];
  }

  Side side = Routes.pages.firstWhereOrNull((page) => page.className == className)?.side ?? Side.fullScreen;
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
