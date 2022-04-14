import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

enum ListMode {
  listWithoutTags,
  listWithTags,
  waterfallFlowWithImageOnly,
  waterfallFlowWithImageAndInfo,
}

enum CoverMode {
  cover,
  contain,
}

class StyleSetting {
  static Rx<Locale> language = window.locale.obs;
  static RxBool enableTagZHTranslation = false.obs;
  static Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  static Rx<ListMode> listMode = ListMode.listWithoutTags.obs;
  static Rx<CoverMode> coverMode = CoverMode.cover.obs;

  /// if enableTabletLayout is true, currentEnableTabletLayout can also be false because of screen width limit.
  static RxBool enableTabletLayout =
      WidgetsBinding.instance!.window.physicalSize.width / WidgetsBinding.instance!.window.devicePixelRatio < 600
          ? false.obs
          : true.obs;
  static RxBool currentEnableTabletLayout = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('styleSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init StyleSetting success', false);
    } else {
      Log.verbose('init StyleSetting success: default', false);
    }
  }

  static saveEnableTagZHTranslation(bool enableTagZHTranslation) {
    StyleSetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static saveThemeMode(ThemeMode themeMode) {
    StyleSetting.themeMode.value = themeMode;
    _save();
    Get.changeThemeMode(themeMode);
  }

  static saveListMode(ListMode listMode) {
    StyleSetting.listMode.value = listMode;
    _save();
  }

  static saveCoverMode(CoverMode coverMode) {
    StyleSetting.coverMode.value = coverMode;
    _save();
  }

  static saveEnableTabletLayout(bool enableTabletLayout) {
    StyleSetting.enableTabletLayout.value = enableTabletLayout;
    _save();
  }

  static ThemeData getCurrentThemeData() {
    return themeMode.value == ThemeMode.dark
        ? ThemeConfig.dark
        : themeMode.value == ThemeMode.light
            ? ThemeConfig.light
            : WidgetsBinding.instance!.window.platformBrightness == Brightness.dark
                ? ThemeConfig.dark
                : ThemeConfig.light;
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('styleSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableTagZHTranslation': enableTagZHTranslation.value,
      'themeMode': themeMode.value.index,
      'listMode': listMode.value.index,
      'coverMode': coverMode.value.index,
      'enableTabletLayout': enableTabletLayout.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableTagZHTranslation.value = map['enableTagZHTranslation'];
    themeMode.value = ThemeMode.values[map['themeMode']];
    listMode.value = ListMode.values[map['listMode']];
    coverMode.value = CoverMode.values[map['coverMode']];
    enableTabletLayout.value = map['enableTabletLayout'];
    currentEnableTabletLayout.value = map['enableTabletLayout'];
  }
}
