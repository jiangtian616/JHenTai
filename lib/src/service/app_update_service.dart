import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../utils/log.dart';

class AppUpdateService extends GetxService {
  StorageService storageService = Get.find();

  static const int appVersion = 1;

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

    if (appVersion > oldVersion) {
      handleAppUpdate();
    }
  }

  void handleFirstOpen() {
    if (StyleSetting.locale.value.languageCode == 'zh') {
      StyleSetting.saveEnableTagZHTranslation(true);
      Get.find<TagTranslationService>().refresh();
    }
  }

  void handleAppUpdate() {}
}
