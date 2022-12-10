import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/utils/locale_util.dart';
import 'package:jhentai/src/utils/log.dart';

import '../model/jh_layout.dart';
import '../service/storage_service.dart';

enum ListMode {
  listWithoutTags,
  listWithTags,
  waterfallFlowWithImageOnly,
  waterfallFlowWithImageAndInfo,
  flat,
  flatWithoutTags,
}

class StyleSetting {
  static Rx<Locale> locale = computeDefaultLocale(window.locale).obs;
  static RxBool enableTagZHTranslation = false.obs;
  static Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  static Rx<ListMode> listMode = ListMode.listWithTags.obs;
  static RxnInt crossAxisCountInWaterFallFlow = RxnInt(null);
  static RxnInt crossAxisCountInGridDownloadPageForGroup = RxnInt(null);
  static RxnInt crossAxisCountInGridDownloadPageForGallery = RxnInt(null);
  static RxMap<String, ListMode> pageListMode = <String, ListMode>{}.obs;
  static RxBool moveCover2RightSide = false.obs;
  static Rx<LayoutMode> layout = WidgetsBinding.instance.window.physicalSize.width / WidgetsBinding.instance.window.devicePixelRatio < 600
      ? LayoutMode.mobileV2.obs
      : GetPlatform.isDesktop
          ? LayoutMode.desktop.obs
          : LayoutMode.tabletV2.obs;
  static RxBool hideBottomBar = false.obs;
  static RxBool alwaysShowScroll2TopButton = false.obs;
  static RxBool enableQuickSearchDrawerGesture = true.obs;

  static bool get isInWaterFlowListMode =>
      listMode.value == ListMode.waterfallFlowWithImageAndInfo || listMode.value == ListMode.waterfallFlowWithImageOnly;

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

  static saveLanguage(Locale locale) async {
    Log.debug('saveLanguage:$locale');
    StyleSetting.locale.value = locale;
    _save();
    Get.updateLocale(locale);
    TabBarSetting.reset();
  }

  static saveEnableTagZHTranslation(bool enableTagZHTranslation) {
    Log.debug('saveEnableTagZHTranslation:$enableTagZHTranslation');
    StyleSetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static saveThemeMode(ThemeMode themeMode) {
    Log.debug('saveThemeMode:${themeMode.name}');
    StyleSetting.themeMode.value = themeMode;
    _save();
    Get.changeThemeMode(themeMode);
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

  static saveHideBottomBar(bool hideBottomBar) {
    Log.debug('saveHideBottomBar:$hideBottomBar');
    StyleSetting.hideBottomBar.value = hideBottomBar;
    _save();
  }

  static saveEnableQuickSearchDrawerGesture(bool enableQuickSearchDrawerGesture) {
    Log.debug('saveEnableQuickSearchDrawerGesture:$enableQuickSearchDrawerGesture');
    StyleSetting.enableQuickSearchDrawerGesture.value = enableQuickSearchDrawerGesture;
    _save();
  }

  static saveAlwaysShowScroll2TopButton(bool alwaysShowScroll2TopButton) {
    Log.debug('saveAlwaysShowScroll2TopButton:$alwaysShowScroll2TopButton');
    StyleSetting.alwaysShowScroll2TopButton.value = alwaysShowScroll2TopButton;
    _save();
  }

  static ThemeData getCurrentThemeData() {
    return themeMode.value == ThemeMode.dark
        ? ThemeConfig.dark
        : themeMode.value == ThemeMode.light
            ? ThemeConfig.light
            : WidgetsBinding.instance.window.platformBrightness == Brightness.dark
                ? ThemeConfig.dark
                : ThemeConfig.light;
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('styleSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'locale': locale.value.toString(),
      'enableTagZHTranslation': enableTagZHTranslation.value,
      'themeMode': themeMode.value.index,
      'listMode': listMode.value.index,
      'crossAxisCountInWaterFallFlow': crossAxisCountInWaterFallFlow.value,
      'crossAxisCountInGridDownloadPageForGroup': crossAxisCountInGridDownloadPageForGroup.value,
      'crossAxisCountInGridDownloadPageForGallery': crossAxisCountInGridDownloadPageForGallery.value,
      'pageListMode': pageListMode.map((route, listMode) => MapEntry(route, listMode.index)),
      'moveCover2RightSide': moveCover2RightSide.value,
      'layout': layout.value.index,
      'enableQuickSearchDrawerGesture': enableQuickSearchDrawerGesture.value,
      'hideBottomBar': hideBottomBar.value,
      'alwaysShowScroll2TopButton': alwaysShowScroll2TopButton.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    locale.value = localeCode2Locale(map['locale']);
    enableTagZHTranslation.value = map['enableTagZHTranslation'];
    themeMode.value = ThemeMode.values[map['themeMode']];
    listMode.value = ListMode.values[map['listMode']];
    crossAxisCountInWaterFallFlow.value = map['crossAxisCountInWaterFallFlow'];
    crossAxisCountInGridDownloadPageForGroup.value = map['crossAxisCountInGridDownloadPageForGroup'];
    crossAxisCountInGridDownloadPageForGallery.value = map['crossAxisCountInGridDownloadPageForGallery'];
    pageListMode.value = Map.from(map['pageListMode']?.map((route, listModeIndex) => MapEntry(route, ListMode.values[listModeIndex])) ?? {});
    moveCover2RightSide.value = map['moveCover2RightSide'] ?? moveCover2RightSide.value;
    layout.value = LayoutMode.values[map['layout'] ?? layout.value.index];

    /// old layout has been removed in v5.0.0
    if (isInV1Layout) {
      layout = WidgetsBinding.instance.window.physicalSize.width / WidgetsBinding.instance.window.devicePixelRatio < 600
          ? LayoutMode.mobileV2.obs
          : GetPlatform.isDesktop
              ? LayoutMode.desktop.obs
              : LayoutMode.tabletV2.obs;
    }
    actualLayout = layout.value;
    enableQuickSearchDrawerGesture.value = map['enableQuickSearchDrawerGesture'] ?? enableQuickSearchDrawerGesture.value;
    hideBottomBar.value = map['hideBottomBar'] ?? hideBottomBar.value;
    alwaysShowScroll2TopButton.value = map['alwaysShowScroll2TopButton'] ?? alwaysShowScroll2TopButton.value;
  }
}
