import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../service/storage_service.dart';
import '../utils/log.dart';

class SiteSetting {
  static Rx<FrontPageDisplayType> frontPageDisplayType = FrontPageDisplayType.compact.obs;

  static RxBool isLargeThumbnail = false.obs;
  static RxInt thumbnailRows = 4.obs;
  static RxInt thumbnailsCountPerPage = 40.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('siteSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init SiteSetting success', false);
    }

    /// listen to login and logout
    ever(UserSetting.userName, (v) {
      if (UserSetting.hasLoggedIn()) {
        refresh();
      } else {
        _clear();
      }
    });
  }

  static Future<void> refresh() async {
    if (!UserSetting.hasLoggedIn()) {
      return;
    }
    Map<String, dynamic> map = await EHRequest.requestSetting(EHSpiderParser.setting2SiteSetting);
    frontPageDisplayType.value = map['frontPageDisplayType'];
    isLargeThumbnail.value = map['isLargeThumbnail'];
    thumbnailRows.value = map['thumbnailRows'];
    thumbnailsCountPerPage.value = thumbnailRows.value * (isLargeThumbnail.value ? 5 : 10);
    Log.info('refresh SiteSetting success', false);
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('siteSetting', _toMap());
  }

  static Future<void> _clear() async {
    isLargeThumbnail.value = false;
    thumbnailRows.value = 4;
    thumbnailsCountPerPage.value = 40;
    _save();
    Log.info('clear SiteSetting success', false);
  }

  static Map<String, dynamic> _toMap() {
    return {
      'frontPageDisplayType': frontPageDisplayType.value.index,
      'isLargeThumbnail': isLargeThumbnail.value,
      'thumbnailRows': thumbnailRows.value,
      'thumbnailsCountPerPage': thumbnailsCountPerPage.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    frontPageDisplayType.value = FrontPageDisplayType.values[map['frontPageDisplayType']];
    isLargeThumbnail.value = map['isLargeThumbnail'];
    thumbnailRows.value = map['thumbnailRows'];
    thumbnailsCountPerPage.value = map['thumbnailsCountPerPage'];
  }
}

enum FrontPageDisplayType {
  minimal,
  minimalPlus,
  compact,
  extended,
  thumbnail,
}
