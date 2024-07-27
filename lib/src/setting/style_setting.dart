import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/log.dart';

import '../model/jh_layout.dart';

StyleSetting styleSetting = StyleSetting();

class StyleSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  Rx<Color> lightThemeColor = UIConfig.defaultLightThemeColor.obs;
  Rx<Color> darkThemeColor = UIConfig.defaultDarkThemeColor.obs;
  Rx<ListMode> listMode = ListMode.listWithTags.obs;
  RxnInt crossAxisCountInWaterFallFlow = RxnInt(null);
  RxnInt crossAxisCountInGridDownloadPageForGroup = RxnInt(null);
  RxnInt crossAxisCountInGridDownloadPageForGallery = RxnInt(null);
  RxnInt crossAxisCountInDetailPage = RxnInt(null);
  RxMap<String, ListMode> pageListMode = <String, ListMode>{}.obs;
  RxBool moveCover2RightSide = false.obs;
  Rx<LayoutMode> layout = PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio < 600
      ? LayoutMode.mobileV2.obs
      : GetPlatform.isDesktop
          ? LayoutMode.desktop.obs
          : LayoutMode.tabletV2.obs;

  bool get isInWaterFlowListMode =>
      listMode.value == ListMode.waterfallFlowBig || listMode.value == ListMode.waterfallFlowSmall || listMode.value == ListMode.waterfallFlowMedium;

  Brightness currentBrightness() => themeMode.value == ThemeMode.system
      ? PlatformDispatcher.instance.platformBrightness
      : themeMode.value == ThemeMode.light
          ? Brightness.light
          : Brightness.dark;

  /// If the current window width is too small, App will degrade to mobile mode. Use [actualLayout] to indicate actual layout.
  LayoutMode actualLayout = PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio < 600
      ? LayoutMode.mobileV2
      : GetPlatform.isDesktop
          ? LayoutMode.desktop
          : LayoutMode.tabletV2;

  bool get isInMobileLayout => actualLayout == LayoutMode.mobileV2 || actualLayout == LayoutMode.mobile;

  bool get isInTabletLayout => actualLayout == LayoutMode.tabletV2 || actualLayout == LayoutMode.tablet;

  bool get isInV1Layout => actualLayout == LayoutMode.mobile || actualLayout == LayoutMode.tablet;

  bool get isInV2Layout => actualLayout == LayoutMode.mobileV2 || actualLayout == LayoutMode.tabletV2;

  bool get isInDesktopLayout => actualLayout == LayoutMode.desktop;

  @override
  ConfigEnum get configEnum => ConfigEnum.styleSetting;

  @override
  void applyConfig(String configString) {
    Map map = jsonDecode(configString);

    themeMode.value = ThemeMode.values[map['themeMode']];
    lightThemeColor.value = Color(map['lightThemeColor'] ?? lightThemeColor.value.value);
    darkThemeColor.value = Color(map['darkThemeColor'] ?? darkThemeColor.value.value);
    listMode.value = ListMode.values[map['listMode']];
    crossAxisCountInWaterFallFlow.value = map['crossAxisCountInWaterFallFlow'];
    crossAxisCountInGridDownloadPageForGroup.value = map['crossAxisCountInGridDownloadPageForGroup'];
    crossAxisCountInGridDownloadPageForGallery.value = map['crossAxisCountInGridDownloadPageForGallery'];
    crossAxisCountInDetailPage.value = map['crossAxisCountInDetailPage'];
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

  @override
  String toConfigString() {
    return jsonEncode({
      'themeMode': themeMode.value.index,
      'lightThemeColor': lightThemeColor.value.value,
      'darkThemeColor': darkThemeColor.value.value,
      'listMode': listMode.value.index,
      'crossAxisCountInWaterFallFlow': crossAxisCountInWaterFallFlow.value,
      'crossAxisCountInGridDownloadPageForGroup': crossAxisCountInGridDownloadPageForGroup.value,
      'crossAxisCountInGridDownloadPageForGallery': crossAxisCountInGridDownloadPageForGallery.value,
      'crossAxisCountInDetailPage': crossAxisCountInDetailPage.value,
      'pageListMode': pageListMode.map((route, listMode) => MapEntry(route, listMode.index)),
      'moveCover2RightSide': moveCover2RightSide.value,
      'layout': layout.value.index,
    });
  }
  
  @override
  Future<void> doInitBean() async {
    ever(themeMode, (_) {
      Get.changeThemeMode(themeMode.value);
    });
  }

  @override
  void doAfterBeanReady() {}

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    log.debug('saveThemeMode:${themeMode.name}');
    this.themeMode.value = themeMode;
    await save();
  }

  Future<void> saveLightThemeColor(Color color) async {
    log.debug('saveLightThemeColor:$color');
    this.lightThemeColor.value = color;
    await save();
  }

  Future<void> saveDarkThemeColor(Color color) async {
    log.debug('saveDarkThemeColor:$color');
    this.darkThemeColor.value = color;
    await save();
  }

  Future<void> saveListMode(ListMode listMode) async {
    log.debug('saveListMode:${listMode.name}');
    this.listMode.value = listMode;
    await save();
  }

  Future<void> saveCrossAxisCountInWaterFallFlow(int? crossAxisCountInWaterFallFlow) async {
    log.debug('saveCrossAxisCountInWaterFallFlow:$crossAxisCountInWaterFallFlow');
    this.crossAxisCountInWaterFallFlow.value = crossAxisCountInWaterFallFlow;
    await save();
  }

  Future<void> saveCrossAxisCountInGridDownloadPageForGroup(int? crossAxisCountInGridDownloadPageForGroup) async {
    log.debug('saveCrossAxisCountInGridDownloadPageForGroup:$crossAxisCountInGridDownloadPageForGroup');
    this.crossAxisCountInGridDownloadPageForGroup.value = crossAxisCountInGridDownloadPageForGroup;
    await save();
  }

  Future<void> saveCrossAxisCountInGridDownloadPageForGallery(int? crossAxisCountInGridDownloadPageForGallery) async {
    log.debug('saveCrossAxisCountInGridDownloadPageForGallery:$crossAxisCountInGridDownloadPageForGallery');
    this.crossAxisCountInGridDownloadPageForGallery.value = crossAxisCountInGridDownloadPageForGallery;
    await save();
  }

  Future<void> saveCrossAxisCountInDetailPage(int? crossAxisCountInDetailPage) async {
    log.debug('saveCrossAxisCountInDetailPage:$crossAxisCountInDetailPage');
    this.crossAxisCountInDetailPage.value = crossAxisCountInDetailPage;
    await save();
  }

  Future<void> savePageListMode(String routeName, ListMode? listMode) async {
    log.debug('savePageListMode:$routeName, $listMode');
    if (listMode == null) {
      this.pageListMode.remove(routeName);
    } else {
      this.pageListMode[routeName] = listMode;
    }
    await save();
  }

  Future<void> saveMoveCover2RightSide(bool moveCover2RightSide) async {
    log.debug('saveMoveCover2RightSide:$moveCover2RightSide');
    this.moveCover2RightSide.value = moveCover2RightSide;
    await save();
  }

  Future<void> saveLayoutMode(LayoutMode layoutMode) async {
    log.debug('saveLayoutMode:${layoutMode.name}');
    this.layout.value = layoutMode;
    await save();
  }
}

enum ListMode {
  listWithoutTags,
  listWithTags,
  waterfallFlowSmall,
  waterfallFlowBig,
  flat,
  flatWithoutTags,
  waterfallFlowMedium,
}
