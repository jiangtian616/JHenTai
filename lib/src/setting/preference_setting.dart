import 'dart:ui';

import 'package:get/get.dart';
import 'package:jhentai/src/model/tab_bar_icon.dart';
import 'package:jhentai/src/setting/tab_bar_setting.dart';

import '../service/storage_service.dart';
import '../utils/locale_util.dart';
import '../utils/log.dart';

class PreferenceSetting {
  static Rx<Locale> locale = computeDefaultLocale(PlatformDispatcher.instance.locale).obs;
  static RxBool enableTagZHTranslation = false.obs;
  static Rx<TabBarIconNameEnum> defaultTab = TabBarIconNameEnum.home.obs;
  static RxBool hideBottomBar = false.obs;
  static RxBool alwaysShowScroll2TopButton = false.obs;
  static RxBool enableSwipeBackGesture = true.obs;
  static RxBool enableLeftMenuDrawerGesture = true.obs;
  static RxBool enableQuickSearchDrawerGesture = true.obs;
  static RxInt drawerGestureEdgeWidth = 20.obs;
  static RxBool showComments = true.obs;
  static RxBool showAllComments = false.obs;
  static RxBool enableDefaultFavorite = false.obs;
  static RxBool showR18GImageDirectly = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('preferenceSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init PreferenceSetting success', false);
    } else {
      Log.debug('init PreferenceSetting success: default', false);
    }
  }

  static saveLanguage(Locale locale) async {
    Log.debug('saveLanguage:$locale');
    PreferenceSetting.locale.value = locale;
    _save();
    Get.updateLocale(locale);
    TabBarSetting.reset();
  }

  static saveDefaultTab(TabBarIconNameEnum defaultTab) {
    Log.debug('saveDefaultTab:$defaultTab');
    PreferenceSetting.defaultTab.value = defaultTab;
    _save();
  }

  static saveEnableTagZHTranslation(bool enableTagZHTranslation) {
    Log.debug('saveEnableTagZHTranslation:$enableTagZHTranslation');
    PreferenceSetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static saveHideBottomBar(bool hideBottomBar) {
    Log.debug('saveHideBottomBar:$hideBottomBar');
    PreferenceSetting.hideBottomBar.value = hideBottomBar;
    _save();
  }

  static saveEnableSwipeBackGesture(bool enableSwipeBackGesture) {
    Log.debug('saveEnableSwipeBackGesture:$enableSwipeBackGesture');
    PreferenceSetting.enableSwipeBackGesture.value = enableSwipeBackGesture;
    _save();
  }

  static saveEnableLeftMenuDrawerGesture(bool enableLeftMenuDrawerGesture) {
    Log.debug('saveEnableLeftMenuDrawerGesture:$enableLeftMenuDrawerGesture');
    PreferenceSetting.enableLeftMenuDrawerGesture.value = enableLeftMenuDrawerGesture;
    _save();
  }

  static saveEnableQuickSearchDrawerGesture(bool enableQuickSearchDrawerGesture) {
    Log.debug('saveEnableQuickSearchDrawerGesture:$enableQuickSearchDrawerGesture');
    PreferenceSetting.enableQuickSearchDrawerGesture.value = enableQuickSearchDrawerGesture;
    _save();
  }

  static saveDrawerGestureEdgeWidth(int drawerGestureEdgeWidth) {
    Log.debug('saveDrawerGestureEdgeWidth:$drawerGestureEdgeWidth');
    PreferenceSetting.drawerGestureEdgeWidth.value = drawerGestureEdgeWidth;
    _save();
  }

  static saveAlwaysShowScroll2TopButton(bool alwaysShowScroll2TopButton) {
    Log.debug('saveAlwaysShowScroll2TopButton:$alwaysShowScroll2TopButton');
    PreferenceSetting.alwaysShowScroll2TopButton.value = alwaysShowScroll2TopButton;
    _save();
  }

  static saveShowComments(bool showComments) {
    Log.debug('saveShowComments:$showComments');
    PreferenceSetting.showComments.value = showComments;
    _save();
  }

  static saveShowAllComments(bool showAllComments) {
    Log.debug('saveShowAllComments:$showAllComments');
    PreferenceSetting.showAllComments.value = showAllComments;
    _save();
  }
  
  static saveEnableDefaultFavorite(bool enableDefaultFavorite) {
    Log.debug('saveEnableDefaultFavorite:$enableDefaultFavorite');
    PreferenceSetting.enableDefaultFavorite.value = enableDefaultFavorite;
    _save();
  }

  static saveShowR18GImageDirectly(bool showR18GImageDirectly) {
    Log.debug('saveShowR18GImageDirectly:$showR18GImageDirectly');
    PreferenceSetting.showR18GImageDirectly.value = showR18GImageDirectly;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('preferenceSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'locale': locale.value.toString(),
      'showR18GImageDirectly': showR18GImageDirectly.value,
      'enableTagZHTranslation': enableTagZHTranslation.value,
      'defaultTab': defaultTab.value.index, // 'home
      'enableSwipeBackGesture': enableSwipeBackGesture.value,
      'enableLeftMenuDrawerGesture': enableLeftMenuDrawerGesture.value,
      'enableQuickSearchDrawerGesture': enableQuickSearchDrawerGesture.value,
      'drawerGestureEdgeWidth': drawerGestureEdgeWidth.value,
      'hideBottomBar': hideBottomBar.value,
      'alwaysShowScroll2TopButton': alwaysShowScroll2TopButton.value,
      'showComments': showComments.value,
      'showAllComments': showAllComments.value,
      'enableDefaultFavorite': enableDefaultFavorite.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    if ((map['locale'] != null)) {
      locale.value = localeCode2Locale(map['locale']);
    }
    showR18GImageDirectly.value = map['showR18GImageDirectly'] ?? showR18GImageDirectly.value;
    enableSwipeBackGesture.value = map['enableSwipeBackGesture'] ?? enableSwipeBackGesture.value;
    enableTagZHTranslation.value = map['enableTagZHTranslation'] ?? enableTagZHTranslation.value;
    defaultTab.value = TabBarIconNameEnum.values[map['defaultTab'] ?? TabBarIconNameEnum.home.index];
    enableLeftMenuDrawerGesture.value = map['enableLeftMenuDrawerGesture'] ?? enableLeftMenuDrawerGesture.value;
    enableQuickSearchDrawerGesture.value = map['enableQuickSearchDrawerGesture'] ?? enableQuickSearchDrawerGesture.value;
    drawerGestureEdgeWidth.value = map['drawerGestureEdgeWidth'] ?? drawerGestureEdgeWidth.value;
    hideBottomBar.value = map['hideBottomBar'] ?? hideBottomBar.value;
    alwaysShowScroll2TopButton.value = map['alwaysShowScroll2TopButton'] ?? alwaysShowScroll2TopButton.value;
    showComments.value = map['showComments'] ?? showComments.value;
    showAllComments.value = map['showAllComments'] ?? showAllComments.value;
    enableDefaultFavorite.value = map['enableDefaultFavorite'] ?? enableDefaultFavorite.value;
  }
}
