import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class GallerySetting {
  static RxBool enableTagZHTranslation = false.obs;
  static RxBool enableDarkTheme = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('gallerySetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init GallerySetting success', false);
    }
  }

  static saveEnableTagZHTranslation(bool enableTagZHTranslation) {
    GallerySetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static saveEnableDarkTheme(bool enableDarkTheme) {
    GallerySetting.enableDarkTheme.value = enableDarkTheme;
    _save();
    Get.changeTheme(enableDarkTheme ? ThemeConfig.dark : ThemeConfig.light);
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('gallerySetting', _toMap());
  }

  static void clear() {
    enableTagZHTranslation.value = false;
    enableDarkTheme.value = false;
    Get.find<StorageService>().remove('gallerySetting');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableTagZHTranslation': enableTagZHTranslation.value,
      'enableDarkTheme': enableDarkTheme.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableTagZHTranslation.value = map['enableTagZHTranslation'];
    enableDarkTheme.value = map['enableDarkTheme'];
  }
}
