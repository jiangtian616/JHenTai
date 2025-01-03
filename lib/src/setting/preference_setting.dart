import 'dart:convert';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/tab_bar_icon.dart';

import '../service/jh_service.dart';
import '../utils/locale_util.dart';
import '../service/log.dart';

PreferenceSetting preferenceSetting = PreferenceSetting();

class PreferenceSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  Rx<Locale> locale = computeDefaultLocale(PlatformDispatcher.instance.locale).obs;
  RxBool enableTagZHTranslation = false.obs;
  RxBool enableTagZHSearchOrderOptimization = false.obs;
  Rx<TabBarIconNameEnum> defaultTab = TabBarIconNameEnum.home.obs;
  RxBool simpleDashboardMode = false.obs;
  RxBool hideBottomBar = false.obs;
  Rx<Scroll2TopButtonModeEnum> hideScroll2TopButton = Scroll2TopButtonModeEnum.scrollDown.obs;
  RxBool preloadGalleryCover = false.obs;
  RxBool enableSwipeBackGesture = true.obs;
  RxBool enableLeftMenuDrawerGesture = true.obs;
  RxBool enableQuickSearchDrawerGesture = true.obs;
  RxInt drawerGestureEdgeWidth = 100.obs;
  RxBool showAllGalleryTitles = false.obs;
  RxBool showGalleryTagVoteStatus = false.obs;
  RxBool showComments = true.obs;
  RxBool showAllComments = false.obs;
  RxBool enableDefaultFavorite = false.obs;
  RxBool enableDefaultTagSet = true.obs;
  RxBool launchInFullScreen = false.obs;
  Rx<SearchBehaviour> searchBehaviour = SearchBehaviour.inheritAll.obs;
  RxBool showR18GImageDirectly = false.obs;
  RxBool showUtcTime = false.obs;
  RxBool showDawnInfo = false.obs;
  RxBool showHVInfo = false.obs;
  RxBool useBuiltInBlockedUsers = true.obs;
  
  @override
  ConfigEnum get configEnum => ConfigEnum.preferenceSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    if ((map['locale'] != null)) {
      locale.value = localeCode2Locale(map['locale']);
    }
    showR18GImageDirectly.value = map['showR18GImageDirectly'] ?? showR18GImageDirectly.value;
    enableSwipeBackGesture.value = map['enableSwipeBackGesture'] ?? enableSwipeBackGesture.value;
    enableTagZHTranslation.value = map['enableTagZHTranslation'] ?? enableTagZHTranslation.value;
    enableTagZHSearchOrderOptimization.value = map['enableTagZHSearchOrderOptimization'] ?? enableTagZHSearchOrderOptimization.value;
    defaultTab.value = TabBarIconNameEnum.values[map['defaultTab'] ?? TabBarIconNameEnum.home.index];
    preloadGalleryCover.value = map['preloadGalleryCover'] ?? preloadGalleryCover.value;
    enableLeftMenuDrawerGesture.value = map['enableLeftMenuDrawerGesture'] ?? enableLeftMenuDrawerGesture.value;
    enableQuickSearchDrawerGesture.value = map['enableQuickSearchDrawerGesture'] ?? enableQuickSearchDrawerGesture.value;
    drawerGestureEdgeWidth.value = map['drawerGestureEdgeWidth'] ?? drawerGestureEdgeWidth.value;
    simpleDashboardMode.value = map['simpleDashboardMode'] ?? simpleDashboardMode.value;
    hideBottomBar.value = map['hideBottomBar'] ?? hideBottomBar.value;
    hideScroll2TopButton.value = Scroll2TopButtonModeEnum.values[map['hideScroll2TopButton'] ?? Scroll2TopButtonModeEnum.scrollDown.index];
    showAllGalleryTitles.value = map['showAllGalleryTitles'] ?? showAllGalleryTitles.value;
    showGalleryTagVoteStatus.value = map['showGalleryTagVoteStatus'] ?? showGalleryTagVoteStatus.value;
    showComments.value = map['showComments'] ?? showComments.value;
    showAllComments.value = map['showAllComments'] ?? showAllComments.value;
    searchBehaviour.value = SearchBehaviour.values[map['tagSearchConfig'] ?? SearchBehaviour.inheritAll.index];
    enableDefaultFavorite.value = map['enableDefaultFavorite'] ?? enableDefaultFavorite.value;
    enableDefaultTagSet.value = map['enableDefaultTagSet'] ?? enableDefaultTagSet.value;
    launchInFullScreen.value = map['launchInFullScreen'] ?? launchInFullScreen.value;
    showUtcTime.value = map['showUtcTime'] ?? showUtcTime.value;
    showDawnInfo.value = map['showDawnInfo'] ?? showDawnInfo.value;
    showHVInfo.value = map['showHVInfo'] ?? showHVInfo.value;
    useBuiltInBlockedUsers.value = map['useBuiltInBlockedUsers'] ?? useBuiltInBlockedUsers.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'locale': locale.value.toString(),
      'showR18GImageDirectly': showR18GImageDirectly.value,
      'enableTagZHTranslation': enableTagZHTranslation.value,
      'enableTagZHSearchOrderOptimization': enableTagZHSearchOrderOptimization.value,
      'defaultTab': defaultTab.value.index,
      'preloadGalleryCover': preloadGalleryCover.value,
      'enableSwipeBackGesture': enableSwipeBackGesture.value,
      'enableLeftMenuDrawerGesture': enableLeftMenuDrawerGesture.value,
      'enableQuickSearchDrawerGesture': enableQuickSearchDrawerGesture.value,
      'drawerGestureEdgeWidth': drawerGestureEdgeWidth.value,
      'simpleDashboardMode': simpleDashboardMode.value,
      'hideBottomBar': hideBottomBar.value,
      'hideScroll2TopButton': hideScroll2TopButton.value.index,
      'showAllGalleryTitles': showAllGalleryTitles.value,
      'showGalleryTagVoteStatus': showGalleryTagVoteStatus.value,
      'showComments': showComments.value,
      'showAllComments': showAllComments.value,
      'tagSearchConfig': searchBehaviour.value.index,
      'enableDefaultFavorite': enableDefaultFavorite.value,
      'enableDefaultTagSet': enableDefaultTagSet.value,
      'launchInFullScreen': launchInFullScreen.value,
      'showUtcTime': showUtcTime.value,
      'showDawnInfo': showDawnInfo.value,
      'showHVInfo': showHVInfo.value,
      'useBuiltInBlockedUsers': useBuiltInBlockedUsers.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveLanguage(Locale locale) async {
    log.debug('saveLanguage:$locale');
    this.locale.value = locale;
    await saveBeanConfig();
    Get.updateLocale(locale);
  }

  Future<void> saveDefaultTab(TabBarIconNameEnum defaultTab) async {
    log.debug('saveDefaultTab:$defaultTab');
    this.defaultTab.value = defaultTab;
    await saveBeanConfig();
  }

  Future<void> saveEnableTagZHTranslation(bool enableTagZHTranslation) async {
    log.debug('saveEnableTagZHTranslation:$enableTagZHTranslation');
    this.enableTagZHTranslation.value = enableTagZHTranslation;
    await saveBeanConfig();
  }

  Future<void> saveEnableTagZHSearchOrderOptimization(bool enableTagZHSearchOrderOptimization) async {
    log.debug('saveEnableTagZHSearchOrderOptimization:$enableTagZHSearchOrderOptimization');
    this.enableTagZHSearchOrderOptimization.value = enableTagZHSearchOrderOptimization;
    await saveBeanConfig();
  }

  Future<void> saveSimpleDashboardMode(bool simpleDashboardMode) async {
    log.debug('saveSimpleDashboardMode:$simpleDashboardMode');
    this.simpleDashboardMode.value = simpleDashboardMode;
    await saveBeanConfig();
  }

  Future<void> saveHideBottomBar(bool hideBottomBar) async {
    log.debug('saveHideBottomBar:$hideBottomBar');
    this.hideBottomBar.value = hideBottomBar;
    await saveBeanConfig();
  }

  Future<void> savePreloadGalleryCover(bool preloadGalleryCover) async {
    log.debug('savePreloadGalleryCover:$preloadGalleryCover');
    this.preloadGalleryCover.value = preloadGalleryCover;
    await saveBeanConfig();
  }

  Future<void> saveEnableSwipeBackGesture(bool enableSwipeBackGesture) async {
    log.debug('saveEnableSwipeBackGesture:$enableSwipeBackGesture');
    this.enableSwipeBackGesture.value = enableSwipeBackGesture;
    await saveBeanConfig();
  }

  Future<void> saveEnableLeftMenuDrawerGesture(bool enableLeftMenuDrawerGesture) async {
    log.debug('saveEnableLeftMenuDrawerGesture:$enableLeftMenuDrawerGesture');
    this.enableLeftMenuDrawerGesture.value = enableLeftMenuDrawerGesture;
    await saveBeanConfig();
  }

  Future<void> saveEnableQuickSearchDrawerGesture(bool enableQuickSearchDrawerGesture) async {
    log.debug('saveEnableQuickSearchDrawerGesture:$enableQuickSearchDrawerGesture');
    this.enableQuickSearchDrawerGesture.value = enableQuickSearchDrawerGesture;
    await saveBeanConfig();
  }

  Future<void> saveDrawerGestureEdgeWidth(int drawerGestureEdgeWidth) async {
    log.debug('saveDrawerGestureEdgeWidth:$drawerGestureEdgeWidth');
    this.drawerGestureEdgeWidth.value = drawerGestureEdgeWidth;
    await saveBeanConfig();
  }

  Future<void> saveHideScroll2TopButton(Scroll2TopButtonModeEnum hideScroll2TopButton) async {
    log.debug('saveHideScroll2TopButton:$hideScroll2TopButton');
    this.hideScroll2TopButton.value = hideScroll2TopButton;
    await saveBeanConfig();
  }

  Future<void> saveShowAllGalleryTitles(bool showAllGalleryTitles) async {
    log.debug('saveShowAllGalleryTitles:$showAllGalleryTitles');
    this.showAllGalleryTitles.value = showAllGalleryTitles;
    await saveBeanConfig();
  }

  Future<void> saveShowGalleryTagVoteStatus(bool showGalleryTagVoteStatus) async {
    log.debug('saveShowGalleryTagVoteStatus:$showGalleryTagVoteStatus');
    this.showGalleryTagVoteStatus.value = showGalleryTagVoteStatus;
    await saveBeanConfig();
  }

  Future<void> saveShowComments(bool showComments) async {
    log.debug('saveShowComments:$showComments');
    this.showComments.value = showComments;
    await saveBeanConfig();
  }

  Future<void> saveShowAllComments(bool showAllComments) async {
    log.debug('saveShowAllComments:$showAllComments');
    this.showAllComments.value = showAllComments;
    await saveBeanConfig();
  }

  Future<void> saveEnableDefaultFavorite(bool enableDefaultFavorite) async {
    log.debug('saveEnableDefaultFavorite:$enableDefaultFavorite');
    this.enableDefaultFavorite.value = enableDefaultFavorite;
    await saveBeanConfig();
  }

  Future<void> saveEnableDefaultTagSet(bool enableDefaultTagSet) async {
    log.debug('saveEnableDefaultTagSet:$enableDefaultTagSet');
    this.enableDefaultTagSet.value = enableDefaultTagSet;
    await saveBeanConfig();
  }

  Future<void> saveLaunchInFullScreen(bool launchInFullScreen) async {
    log.debug('saveLaunchInFullScreen:$launchInFullScreen');
    this.launchInFullScreen.value = launchInFullScreen;
    await saveBeanConfig();
  }

  Future<void> saveTagSearchConfig(SearchBehaviour tagSearchConfig) async {
    log.debug('saveTagSearchConfig:$tagSearchConfig');
    this.searchBehaviour.value = tagSearchConfig;
    await saveBeanConfig();
  }

  Future<void> saveShowR18GImageDirectly(bool showR18GImageDirectly) async {
    log.debug('saveShowR18GImageDirectly:$showR18GImageDirectly');
    this.showR18GImageDirectly.value = showR18GImageDirectly;
    await saveBeanConfig();
  }

  Future<void> saveShowUtcTime(bool showUtcTime) async {
    log.debug('saveShowUtcTime:$showUtcTime');
    this.showUtcTime.value = showUtcTime;
    await saveBeanConfig();
  }
  
  Future<void> saveShowDawnInfo(bool showDawnInfo) async {
    log.debug('saveShowDawnInfo:$showDawnInfo');
    this.showDawnInfo.value = showDawnInfo;
    await saveBeanConfig();
  }
  
  Future<void> saveShowHVInfo(bool showHVInfo) async {
    log.debug('saveShowHVInfo:$showHVInfo');
    this.showHVInfo.value = showHVInfo;
    await saveBeanConfig();
  }
  
  Future<void> saveUseBuiltInBlockedUsers(bool useBuiltInBlockedUsers) async {
    log.debug('saveUseBuiltInBlockedUsers:$useBuiltInBlockedUsers');
    this.useBuiltInBlockedUsers.value = useBuiltInBlockedUsers;
    await saveBeanConfig();
  }
}

enum Scroll2TopButtonModeEnum { scrollUp, scrollDown, never, always }

enum SearchBehaviour { inheritAll, inheritPartially, none }
