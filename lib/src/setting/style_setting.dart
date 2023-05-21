import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/utils/log.dart';

import '../model/jh_layout.dart';
import '../service/storage_service.dart';

enum ListMode {
  listWithoutTags,
  listWithTags,
  waterfallFlowSmall,
  waterfallFlowBig,
  flat,
  flatWithoutTags,
  waterfallFlowMedium,
}

class StyleSetting {
  static Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  static Rx<Color> lightThemeColor = UIConfig.defaultLightThemeColor.obs;
  static Rx<Color> darkThemeColor = UIConfig.defaultDarkThemeColor.obs;
  static Rx<ListMode> listMode = ListMode.listWithTags.obs;
  static RxnInt crossAxisCountInWaterFallFlow = RxnInt(null);
  static RxnInt crossAxisCountInGridDownloadPageForGroup = RxnInt(null);
  static RxnInt crossAxisCountInGridDownloadPageForGallery = RxnInt(null);
  static RxMap<String, ListMode> pageListMode = <String, ListMode>{}.obs;
  static RxBool moveCover2RightSide = false.obs;
  static Rx<LayoutMode> layout =
      PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio < 600
          ? LayoutMode.mobileV2.obs
          : GetPlatform.isDesktop
              ? LayoutMode.desktop.obs
              : LayoutMode.tabletV2.obs;

  static bool get isInWaterFlowListMode =>
      listMode.value == ListMode.waterfallFlowBig || listMode.value == ListMode.waterfallFlowSmall || listMode.value == ListMode.waterfallFlowMedium;

  static Brightness currentBrightness() => themeMode.value == ThemeMode.system
      ? PlatformDispatcher.instance.platformBrightness
      : themeMode.value == ThemeMode.light
          ? Brightness.light
          : Brightness.dark;

  /// If the current window width is too small, App will degrade to mobile mode. Use [actualLayout] to indicate actual layout.
  static LayoutMode actualLayout = layout.value;

  static bool get isInMobileLayout => actualLayout == LayoutMode.mobileV2 || actualLayout == LayoutMode.mobile;

  static bool get isInTabletLayout => actualLayout == LayoutMode.tabletV2 || actualLayout == LayoutMode.tablet;

  static bool get isInV1Layout => actualLayout == LayoutMode.mobile || actualLayout == LayoutMode.tablet;

  static bool get isInV2Layout => actualLayout == LayoutMode.mobileV2 || actualLayout == LayoutMode.tabletV2;

  static bool get isInDesktopLayout => actualLayout == LayoutMode.desktop;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('styleSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init StyleSetting success', false);
    } else {
      Log.debug('init StyleSetting success: default', false);
    }
  }

  static saveThemeMode(ThemeMode themeMode) {
    Log.debug('saveThemeMode:${themeMode.name}');
    StyleSetting.themeMode.value = themeMode;
    _save();

    Get.changeThemeMode(themeMode);
  }

  static saveLightThemeColor(Color color) {
    Log.debug('saveLightThemeColor:$color');
    StyleSetting.lightThemeColor.value = color;
    _save();
  }

  static saveDarkThemeColor(Color color) {
    Log.debug('saveDarkThemeColor:$color');
    StyleSetting.darkThemeColor.value = color;
    _save();
  }

  static saveListMode(ListMode listMode) {
    Log.debug('saveListMode:${listMode.name}');
    StyleSetting.listMode.value = listMode;
    _save();
  }

  static saveCrossAxisCountInWaterFallFlow(int? crossAxisCountInWaterFallFlow) {
    Log.debug('saveCrossAxisCountInWaterFallFlow:$crossAxisCountInWaterFallFlow');
    StyleSetting.crossAxisCountInWaterFallFlow.value = crossAxisCountInWaterFallFlow;
    _save();
  }

  static saveCrossAxisCountInGridDownloadPageForGroup(int? crossAxisCountInGridDownloadPageForGroup) {
    Log.debug('saveCrossAxisCountInGridDownloadPageForGroup:$crossAxisCountInGridDownloadPageForGroup');
    StyleSetting.crossAxisCountInGridDownloadPageForGroup.value = crossAxisCountInGridDownloadPageForGroup;
    _save();
  }

  static saveCrossAxisCountInGridDownloadPageForGallery(int? crossAxisCountInGridDownloadPageForGallery) {
    Log.debug('saveCrossAxisCountInGridDownloadPageForGallery:$crossAxisCountInGridDownloadPageForGallery');
    StyleSetting.crossAxisCountInGridDownloadPageForGallery.value = crossAxisCountInGridDownloadPageForGallery;
    _save();
  }

  static savePageListMode(String routeName, ListMode? listMode) {
    Log.debug('savePageListMode:$routeName, $listMode');
    if (listMode == null) {
      StyleSetting.pageListMode.remove(routeName);
    } else {
      StyleSetting.pageListMode[routeName] = listMode;
    }
    _save();
  }

  static saveMoveCover2RightSide(bool moveCover2RightSide) {
    Log.debug('saveMoveCover2RightSide:$moveCover2RightSide');
    StyleSetting.moveCover2RightSide.value = moveCover2RightSide;
    _save();
  }

  static saveLayoutMode(LayoutMode layoutMode) {
    Log.debug('saveLayoutMode:${layoutMode.name}');
    StyleSetting.layout.value = layoutMode;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('styleSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'themeMode': themeMode.value.index,
      'lightThemeColor': lightThemeColor.value.value,
      'darkThemeColor': darkThemeColor.value.value,
      'listMode': listMode.value.index,
      'crossAxisCountInWaterFallFlow': crossAxisCountInWaterFallFlow.value,
      'crossAxisCountInGridDownloadPageForGroup': crossAxisCountInGridDownloadPageForGroup.value,
      'crossAxisCountInGridDownloadPageForGallery': crossAxisCountInGridDownloadPageForGallery.value,
      'pageListMode': pageListMode.map((route, listMode) => MapEntry(route, listMode.index)),
      'moveCover2RightSide': moveCover2RightSide.value,
      'layout': layout.value.index,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    themeMode.value = ThemeMode.values[map['themeMode']];
    lightThemeColor.value = Color(map['lightThemeColor'] ?? lightThemeColor.value.value);
    darkThemeColor.value = Color(map['darkThemeColor'] ?? darkThemeColor.value.value);
    listMode.value = ListMode.values[map['listMode']];
    crossAxisCountInWaterFallFlow.value = map['crossAxisCountInWaterFallFlow'];
    crossAxisCountInGridDownloadPageForGroup.value = map['crossAxisCountInGridDownloadPageForGroup'];
    crossAxisCountInGridDownloadPageForGallery.value = map['crossAxisCountInGridDownloadPageForGallery'];
    pageListMode.value = Map.from(map['pageListMode']?.map((route, listModeIndex) => MapEntry(route, ListMode.values[listModeIndex])) ?? {});
    moveCover2RightSide.value = map['moveCover2RightSide'] ?? moveCover2RightSide.value;
    layout.value = LayoutMode.values[map['layout'] ?? layout.value.index];

    /// old layout has been removed in v5.0.0
    if (isInV1Layout) {
      layout = PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio < 600
          ? LayoutMode.mobileV2.obs
          : GetPlatform.isDesktop
              ? LayoutMode.desktop.obs
              : LayoutMode.tabletV2.obs;
    }
    actualLayout = layout.value;
  }
}
