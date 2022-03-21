import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class GallerySetting {
  static RxBool enableTagZHTranslation = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('gallerySetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init GallerySetting success', false);
    }
  }

  static saveTagZHTranslation(bool enableTagZHTranslation) {
    GallerySetting.enableTagZHTranslation.value = enableTagZHTranslation;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('gallerySetting', _toMap());
  }

  static void clear() {
    enableTagZHTranslation.value = false;
    Get.find<StorageService>().remove('gallerySetting');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enableTagZHTranslation': enableTagZHTranslation.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enableTagZHTranslation.value = map['enableTagZHTranslation'];
  }
}
