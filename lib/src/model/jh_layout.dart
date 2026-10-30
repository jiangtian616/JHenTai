import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum LayoutMode {
  mobile,
  tablet,
  desktop,
  mobileV2,
  tabletV2,
  automatic,
}

LayoutMode resolveLayoutMode(LayoutMode preferred, double width, {bool isDesktop = false}) {
  if (preferred == LayoutMode.mobile || preferred == LayoutMode.mobileV2 || width < 600) {
    return LayoutMode.mobileV2;
  }
  if (preferred == LayoutMode.automatic) {
    return isDesktop ? LayoutMode.desktop : LayoutMode.tabletV2;
  }
  return preferred == LayoutMode.tablet ? LayoutMode.tabletV2 : preferred;
}

class JHLayout {
  final LayoutMode mode;

  final String name;

  final String desc;

  final ValueGetter<bool> isSupported;

  JHLayout({
    required this.mode,
    required this.name,
    required this.desc,
    required this.isSupported,
  });

  static List<JHLayout> get allLayouts => [
        JHLayout(
          mode: LayoutMode.automatic,
          name: 'auto'.tr,
          desc: '${'mobileLayoutV2Name'.tr} / ${'tabletLayoutV2Name'.tr}',
          isSupported: () => true,
        ),
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
          isSupported: () =>
              PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600,
        ),
        JHLayout(
          mode: LayoutMode.desktop,
          name: 'desktopLayoutName'.tr,
          desc: 'desktopLayoutDesc'.tr,
          isSupported: () =>
              PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600,
        ),
      ];
}
