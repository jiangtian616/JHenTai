import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';

import '../setting/preference_setting.dart';
import '../utils/locale_util.dart';
import '../utils/log.dart';

class AppUpdateService extends GetxService {
  StorageService storageService = Get.find();

  static const int appVersion = 2;

  static void init() {
    Get.put(AppUpdateService(), permanent: true);
  }

  @override
  void onInit() async {
    super.onInit();

    int? oldVersion = storageService.read('appVersion');
    storageService.write('appVersion', appVersion);
    Log.debug('App old version: $oldVersion, current version: $appVersion');

    if (oldVersion == null) {
      handleFirstOpen();
      return;
    }

    handleAppUpdate(oldVersion);

    if (appVersion > oldVersion) {
      Log.info('AppUpdateService update from $oldVersion to $appVersion');
      handleAppUpdate(oldVersion);
    }
  }

  void handleFirstOpen() {
    if (PreferenceSetting.locale.value.languageCode == 'zh') {
      PreferenceSetting.saveEnableTagZHTranslation(true);
      Get.find<TagTranslationService>().refresh();
    }
  }

  void handleAppUpdate(int oldVersion) async {
    if (oldVersion <= 2) {
      Map<String, dynamic>? styleSettingMap = Get.find<StorageService>().read<Map<String, dynamic>>('styleSetting');

      if (styleSettingMap?['locale'] != null) {
        PreferenceSetting.saveLanguage(localeCode2Locale(styleSettingMap!['locale']));
      }
      if (styleSettingMap?['enableTagZHTranslation'] != null) {
        PreferenceSetting.saveEnableTagZHTranslation(styleSettingMap!['enableTagZHTranslation']);
      }
      if (styleSettingMap?['showR18GImageDirectly'] != null) {
        PreferenceSetting.saveShowR18GImageDirectly(styleSettingMap!['showR18GImageDirectly']);
      }
      if (styleSettingMap?['enableQuickSearchDrawerGesture'] != null) {
        PreferenceSetting.saveEnableQuickSearchDrawerGesture(styleSettingMap!['enableQuickSearchDrawerGesture']);
      }
      if (styleSettingMap?['hideBottomBar'] != null) {
        PreferenceSetting.saveHideBottomBar(styleSettingMap!['hideBottomBar']);
      }
      if (styleSettingMap?['alwaysShowScroll2TopButton'] != null) {
        PreferenceSetting.saveAlwaysShowScroll2TopButton(styleSettingMap!['alwaysShowScroll2TopButton']);
      }
    }
  }
}
