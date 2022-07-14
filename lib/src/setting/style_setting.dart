import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';
import 'package:jhentai/src/utils/locale_util.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

enum ListMode {
  listWithoutTags,
  listWithTags,
  waterfallFlowWithImageOnly,
  waterfallFlowWithImageAndInfo,
  flat,
}

enum CoverMode {
  cover,
  contain,
}

enum LayoutMode {
  mobile,
  tablet,
  desktop,
}

class StyleSetting {
  static Rx<Locale> locale = computeDefaultLocale(window.locale).obs;
  static RxBool enableTagZHTranslation = false.obs;
  static Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  static Rx<ListMode> listMode = ListMode.listWithoutTags.obs;
  static Rx<CoverMode> coverMode = CoverMode.cover.obs;

  static Rx<LayoutMode> layoutMode = WidgetsBinding.instance.window.physicalSize.width / WidgetsBinding.instance.window.devicePixelRatio < 600
      ? LayoutMode.mobile.obs
      : GetPlatform.isDesktop
          ? LayoutMode.desktop.obs
          : LayoutMode.tablet.obs;

  /// If the current window width is too small, App will degrade to mobile mode. Use [actualLayoutMode] to indicate actual layout.
  static Rx<LayoutMode> actualLayoutMode = layoutMode.value.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('styleSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init StyleSetting success', false);
    } else {
      Log.verbose('init StyleSetting success: default', false);
    }
  }

  static saveLanguage(Locale locale) async {
    Log.verbose('saveLanguage:$locale');
    StyleSetting.locale.value = locale;
    _save();
    Get.updateLocale(locale);
    TabBarSetting.reset();
  }

  static saveEnableTagZHTranslation(bool enableTagZHTranslation) {
    Log.verbose('saveEnableTagZHTranslation:$enableTagZHTranslation');
    StyleSetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static saveThemeMode(ThemeMode themeMode) {
    Log.verbose('saveThemeMode:${themeMode.name}');
    StyleSetting.themeMode.value = themeMode;
    _save();
    Get.changeThemeMode(themeMode);
  }

  static saveListMode(ListMode listMode) {
    Log.verbose('saveListMode:${listMode.name}');
    StyleSetting.listMode.value = listMode;
    _save();
  }

  static saveCoverMode(CoverMode coverMode) {
    Log.verbose('saveCoverMode:${coverMode.name}');
    StyleSetting.coverMode.value = coverMode;
    _save();
  }

  static saveLayoutMode(LayoutMode layoutMode) {
    Log.verbose('saveLayoutMode:${layoutMode.name}');
    StyleSetting.layoutMode.value = layoutMode;
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
      'coverMode': coverMode.value.index,
      'layoutMode': layoutMode.value.index,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    locale.value = localeCode2Locale(map['locale']);
    enableTagZHTranslation.value = map['enableTagZHTranslation'];
    themeMode.value = ThemeMode.values[map['themeMode']];
    listMode.value = ListMode.values[map['listMode']];
    coverMode.value = CoverMode.values[map['coverMode']];
    layoutMode.value = LayoutMode.values[map['layoutMode'] ?? layoutMode.value.index];
    actualLayoutMode.value = layoutMode.value;
  }
}
