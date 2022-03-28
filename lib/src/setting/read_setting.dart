import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class ReadSetting {
  static RxBool enablePageTurnAnime = true.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('readSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init ReadSetting success', false);
    }
  }

  static saveEnablePageTurnAnime(bool value) {
    enablePageTurnAnime.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('readSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'enablePageTurnAnime': enablePageTurnAnime.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    enablePageTurnAnime.value = map['enablePageTurnAnime'];
  }
}
