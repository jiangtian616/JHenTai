import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum LayoutMode {
  mobile,
  tablet,
  desktop,
  mobileV2,
  tabletV2,
}

class JHLayout {
  final LayoutMode mode;

  final String name;

  final String desc;

  /// Whether this layout can be applied in current window, layouts except mobile need a window width of at least 600.
  final ValueGetter<bool> isSupported;

  /// Whether this layout can be applied when the screen is in [orientation].
  bool isSupportedIn(Orientation orientation) {
    if (mode == LayoutMode.mobileV2) {
      return true;
    }
    FlutterView view = PlatformDispatcher.instance.views.first;
    Size size = view.physicalSize / view.devicePixelRatio;
    return (orientation == Orientation.landscape ? size.longestSide : size.shortestSide) >= 600;
  }

  JHLayout({
    required this.mode,
    required this.name,
    required this.desc,
    required this.isSupported,
  });

  static List<JHLayout> get allLayouts => [
        JHLayout(
          mode: LayoutMode.mobileV2,
          name: 'mobileLayoutV2Name'.tr,
          desc: 'mobileLayoutV2Desc'.tr,
          isSupported: () => true,
        ),
        JHLayout(
          mode: LayoutMode.tabletV2,
          name: 'tabletLayoutV2Name'.tr,
          desc: 'tabletLayoutV2Desc'.tr,
          isSupported: () => PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600,
        ),
        JHLayout(
          mode: LayoutMode.desktop,
          name: 'desktopLayoutName'.tr,
          desc: 'desktopLayoutDesc'.tr,
          isSupported: () => PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600,
        ),
      ];
}
