import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:retry/retry.dart';

import '../exception/eh_site_exception.dart';
import '../model/profile.dart';
import '../service/storage_service.dart';
import '../utils/log.dart';

class SiteSetting {
  static RxBool preferJapaneseTitle = true.obs;

  /// unused now
  static Rx<FrontPageDisplayType> frontPageDisplayType = FrontPageDisplayType.compact.obs;

  static RxBool isLargeThumbnail = false.obs;
  static RxInt thumbnailRows = 4.obs;
  static RxInt thumbnailsCountPerPage = 40.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>(ConfigEnum.siteSetting.key);
    if (map != null) {
      _initFromMap(map);
      Log.debug('init SiteSetting success', false);
    } else {
      Log.debug('init SiteSetting success: default', false);
    }

    /// listen to login and logout
    ever(UserSetting.ipbMemberId, (v) {
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

    Log.info('refresh SiteSetting');

    ({
      bool preferJapaneseTitle,
      List<Profile> profiles,
      FrontPageDisplayType frontPageDisplayType,
      bool isLargeThumbnail,
      int thumbnailRows,
    }) settings;
    try {
      settings = await retry(
        () => EHRequest.requestSettingPage(EHSpiderParser.settingPage2SiteSetting),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      Log.error('refresh SiteSetting fail', e.errorMsg);
      return;
    } on EHSiteException catch (e) {
      Log.error('refresh SiteSetting fail', e.message);
      return;
    }

    preferJapaneseTitle.value = settings.preferJapaneseTitle;
    frontPageDisplayType.value = settings.frontPageDisplayType;
    isLargeThumbnail.value = settings.isLargeThumbnail;
    thumbnailRows.value = settings.thumbnailRows;
    thumbnailsCountPerPage.value = thumbnailRows.value * (isLargeThumbnail.value ? 5 : 10);

    Log.info('refresh SiteSetting success');
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write(ConfigEnum.siteSetting.key, _toMap());
  }

  static Future<void> _clear() async {
    preferJapaneseTitle.value = true;
    frontPageDisplayType.value = FrontPageDisplayType.compact;
    isLargeThumbnail.value = false;
    thumbnailRows.value = 4;
    thumbnailsCountPerPage.value = 40;
    Get.find<StorageService>().remove(ConfigEnum.siteSetting.key);
    Log.info('clear SiteSetting success');
  }

  static Map<String, dynamic> _toMap() {
    return {
      'preferJapaneseTitle': preferJapaneseTitle.value,
      'frontPageDisplayType': frontPageDisplayType.value.index,
      'isLargeThumbnail': isLargeThumbnail.value,
      'thumbnailRows': thumbnailRows.value,
      'thumbnailsCountPerPage': thumbnailsCountPerPage.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    preferJapaneseTitle.value = map['preferJapaneseTitle'] ?? true;
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
